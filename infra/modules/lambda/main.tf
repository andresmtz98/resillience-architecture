# ── IAM: Level Lambdas (L1, L2, L3) ───────────────────────────────────────
resource "aws_iam_role" "level_exec" {
  name = "ultraseguros-level-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "level_policy" {
  role = aws_iam_role.level_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/ultraseguros-level-*:*"
      },
      {
        Effect   = "Allow"
        Action   = "cloudwatch:PutMetricData"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.metric_namespace
          }
        }
      }
    ]
  })
}

# ── Lambda: Level 1 (Full) ────────────────────────────────────────────────
resource "aws_lambda_function" "level_1" {
  function_name    = "ultraseguros-level-1-full"
  filename         = "${local.handlers_path}/level_1_full/function.zip"
  source_code_hash = try(filebase64sha256("${local.handlers_path}/level_1_full/function.zip"), null)
  handler          = "handler.handler"
  runtime          = local.runtime
  architectures    = local.architectures
  role             = aws_iam_role.level_exec.arn

  environment {
    variables = {
      METRIC_NAMESPACE = local.metric_namespace
    }
  }
}

# ── Lambda: Level 2 (Degraded) ────────────────────────────────────────────
resource "aws_lambda_function" "level_2" {
  function_name    = "ultraseguros-level-2-degraded"
  filename         = "${local.handlers_path}/level_2_degraded/function.zip"
  source_code_hash = try(filebase64sha256("${local.handlers_path}/level_2_degraded/function.zip"), null)
  handler          = "handler.handler"
  runtime          = local.runtime
  architectures    = local.architectures
  role             = aws_iam_role.level_exec.arn

  environment {
    variables = {
      METRIC_NAMESPACE = local.metric_namespace
    }
  }
}

# ── Lambda: Level 3 (Maintenance) ─────────────────────────────────────────
resource "aws_lambda_function" "level_3" {
  function_name    = "ultraseguros-level-3-maintenance"
  filename         = "${local.handlers_path}/level_3_maintenance/function.zip"
  source_code_hash = try(filebase64sha256("${local.handlers_path}/level_3_maintenance/function.zip"), null)
  handler          = "handler.handler"
  runtime          = local.runtime
  architectures    = local.architectures
  role             = aws_iam_role.level_exec.arn

  environment {
    variables = {
      METRIC_NAMESPACE = local.metric_namespace
    }
  }
}

# ── IAM: Level Evaluator (DynamoDB + CloudWatch metrics) ──────────────────
resource "aws_iam_role" "level_evaluator_exec" {
  name = "ultraseguros-level-evaluator-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "level_evaluator_policy" {
  role = aws_iam_role.level_evaluator_exec.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/ultraseguros-level-evaluator:*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = var.state_table_arn
      },
      {
        Effect = "Allow"
        Action = "cloudwatch:PutMetricData"
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = local.metric_namespace
          }
        }
      }
    ]
  })
}

# ── Lambda: Level Evaluator ───────────────────────────────────────────────
resource "aws_lambda_function" "level_evaluator" {
  function_name    = "ultraseguros-level-evaluator"
  filename         = "${local.handlers_path}/level_evaluator/function.zip"
  source_code_hash = try(filebase64sha256("${local.handlers_path}/level_evaluator/function.zip"), null)
  handler          = "handler.handler"
  runtime          = local.runtime
  architectures    = local.architectures
  role             = aws_iam_role.level_evaluator_exec.arn
  timeout          = 10

  environment {
    variables = {
      STATE_TABLE_NAME = var.state_table_name
      METRIC_NAMESPACE = local.metric_namespace
    }
  }
}
