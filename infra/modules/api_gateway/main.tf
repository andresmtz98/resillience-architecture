# ── IAM Role for API Gateway → Step Functions ─────────────────────────────
resource "aws_iam_role" "apigw_sfn" {
  name = "ultraseguros-apigw-sfn"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "apigateway.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "apigw_sfn" {
  role = aws_iam_role.apigw_sfn.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartSyncExecution"
      Resource = var.state_machine_arn
    }]
  })
}

# ── REST API ──────────────────────────────────────────────────────────────
resource "aws_api_gateway_rest_api" "ultra" {
  name = "ultraseguros-api"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "service_api" {
  rest_api_id = aws_api_gateway_rest_api.ultra.id
  parent_id   = aws_api_gateway_rest_api.ultra.root_resource_id
  path_part   = "service-api"
}

resource "aws_api_gateway_method" "post_service_api" {
  rest_api_id   = aws_api_gateway_rest_api.ultra.id
  resource_id   = aws_api_gateway_resource.service_api.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integration: API Gateway → Step Functions StartSyncExecution
resource "aws_api_gateway_integration" "sfn" {
  rest_api_id             = aws_api_gateway_rest_api.ultra.id
  resource_id             = aws_api_gateway_resource.service_api.id
  http_method             = aws_api_gateway_method.post_service_api.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:states:action/StartSyncExecution"
  credentials             = aws_iam_role.apigw_sfn.arn
  passthrough_behavior    = "NEVER"
  content_handling        = "CONVERT_TO_TEXT"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-amz-json-1.0'"
  }

  request_templates = {
    "application/json" = <<-VTL
#set($body = $input.body)
{"stateMachineArn":"${var.state_machine_arn}","input":"{\"body\":$util.escapeJavaScript($body)}"}
VTL
  }
}

resource "aws_api_gateway_method_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.ultra.id
  resource_id = aws_api_gateway_resource.service_api.id
  http_method = aws_api_gateway_method.post_service_api.http_method
  status_code = "200"
}

# Extracts the Lambda response from the Step Functions output and returns it as the API response
resource "aws_api_gateway_integration_response" "post_200" {
  rest_api_id = aws_api_gateway_rest_api.ultra.id
  resource_id = aws_api_gateway_resource.service_api.id
  http_method = aws_api_gateway_method.post_service_api.http_method
  status_code = "200"

  response_templates = {
    "application/json" = "$input.json('$.output')"
  }

  depends_on = [aws_api_gateway_integration.sfn]
}

# ── Deployment + Stage ────────────────────────────────────────────────────
resource "aws_api_gateway_deployment" "ultra" {
  rest_api_id = aws_api_gateway_rest_api.ultra.id
  depends_on  = [aws_api_gateway_integration.sfn]

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_integration.sfn,
      aws_api_gateway_method.post_service_api,
      aws_api_gateway_integration_response.post_200,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.ultra.id
  deployment_id = aws_api_gateway_deployment.ultra.id
  stage_name    = local.stage_name
}
