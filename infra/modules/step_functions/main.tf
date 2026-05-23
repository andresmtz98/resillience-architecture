# ── CloudWatch Log Group for Step Functions ───────────────────────────────
resource "aws_cloudwatch_log_group" "router" {
  name              = "/aws/vendedlogs/states/${local.state_machine_name}"
  retention_in_days = 7
}

# ── IAM Role for Step Functions ───────────────────────────────────────────
resource "aws_iam_role" "router_exec" {
  name = "ultraseguros-router-sfn-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "router_exec" {
  role = aws_iam_role.router_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogDelivery",
          "logs:GetLogDelivery",
          "logs:UpdateLogDelivery",
          "logs:DeleteLogDelivery",
          "logs:ListLogDeliveries",
          "logs:PutResourcePolicy",
          "logs:DescribeResourcePolicies",
          "logs:DescribeLogGroups",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = var.state_table_arn
      },
      {
        Effect = "Allow"
        Action = "lambda:InvokeFunction"
        Resource = [
          var.level_1_arn,
          var.level_2_arn,
          var.level_3_arn
        ]
      }
    ]
  })
}

# ── State Machine ─────────────────────────────────────────────────────────
resource "aws_sfn_state_machine" "router" {
  name     = local.state_machine_name
  role_arn = aws_iam_role.router_exec.arn
  type     = "EXPRESS"

  logging_configuration {
    log_destination        = "${aws_cloudwatch_log_group.router.arn}:*"
    include_execution_data = true
    level                  = "ALL"
  }

  definition = jsonencode({
    Comment = "Routes incoming requests to the appropriate level handler based on system state."
    StartAt = "ReadState"
    States = {

      # 1. Read current system level from DynamoDB
      ReadState = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:getItem"
        Parameters = {
          TableName = var.state_table_name
          Key       = { id = { S = "system" } }
        }
        ResultPath = "$.state"
        Next       = "CheckErrorFlag"
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = 1
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "FailSafeLevel3"
          ResultPath  = "$.error"
        }]
      }

      # 2. If payload.error == true, increment counter
      CheckErrorFlag = {
        Type = "Choice"
        Choices = [{
          Variable      = "$.body.error"
          BooleanEquals = true
          Next          = "CountError"
        }]
        Default = "RouteByLevel"
      }

      CountError = {
        Type     = "Task"
        Resource = "arn:aws:states:::dynamodb:updateItem"
        Parameters = {
          TableName = var.state_table_name
          Key       = { id = { S = "system" } }
          UpdateExpression          = "ADD error_count_current_minute :one"
          ExpressionAttributeValues = { ":one" = { N = "1" } }
        }
        ResultPath = null
        Next       = "RouteByLevel"
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = 1
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "RouteByLevel"
          ResultPath  = "$.error"
        }]
      }

      # 3. Route to the appropriate Lambda based on the current level
      RouteByLevel = {
        Type = "Choice"
        Choices = [
          { Variable = "$.state.Item.level.N", StringEquals = "1", Next = "InvokeLevel1" },
          { Variable = "$.state.Item.level.N", StringEquals = "2", Next = "InvokeLevel2" }
        ]
        Default = "InvokeLevel3"
      }

      InvokeLevel1 = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.level_1_arn
          Payload = {
            "payload.$" = "$.body"
          }
        }
        OutputPath = "$.Payload"
        End        = true
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "FailSafeLevel3"
          ResultPath  = "$.error"
        }]
      }

      InvokeLevel2 = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.level_2_arn
          Payload = {
            "payload.$" = "$.body"
          }
        }
        OutputPath = "$.Payload"
        End        = true
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "FailSafeLevel3"
          ResultPath  = "$.error"
        }]
      }

      InvokeLevel3 = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.level_3_arn
          Payload = {
            "payload.$" = "$.body"
          }
        }
        OutputPath = "$.Payload"
        End        = true
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "FailSafeLevel3"
          ResultPath  = "$.error"
        }]
      }

      # Fail-safe: if InvokeLevel{1,2} fail, retry through L3 Lambda
      FailSafeLevel3 = {
        Type     = "Task"
        Resource = "arn:aws:states:::lambda:invoke"
        Parameters = {
          FunctionName = var.level_3_arn
          Payload = {
            "payload.$" = "$.body"
          }
        }
        OutputPath = "$.Payload"
        End        = true
        Retry = [{
          ErrorEquals     = ["Lambda.ServiceException", "Lambda.AWSLambdaException", "Lambda.SdkClientException", "Lambda.TooManyRequestsException"]
          IntervalSeconds = 1
          MaxAttempts     = 2
          BackoffRate     = 2.0
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "HardcodedMaintenance"
          ResultPath  = "$.error"
        }]
      }

      # Last-resort fallback: synthesize a maintenance response without
      # invoking any Lambda. Guarantees the API never returns a 5xx as long
      # as the state machine itself runs.
      HardcodedMaintenance = {
        Type = "Pass"
        Result = {
          level         = 3
          message       = "Nivel 3: Sistema bajo mantenimiento, intente más tarde"
          source        = "fail-safe"
        }
        End = true
      }
    }
  })
}
