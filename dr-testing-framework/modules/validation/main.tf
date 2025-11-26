variable "project_name" {
  description = "Name of the project being tested"
  type        = string
}

variable "validation_checks" {
  description = "List of validation checks to perform"
  type        = list(string)
  default     = ["data_integrity", "service_availability", "response_time"]
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
}

# Lambda function for validation checks
resource "aws_lambda_function" "validation" {
  function_name = "${var.project_name}-dr-validation"
  handler       = "index.handler"
  role          = aws_iam_role.validation_lambda_role.arn
  runtime       = "nodejs14.x"
  timeout       = 300
  memory_size   = 256

  environment {
    variables = {
      PROJECT_NAME      = var.project_name
      PRIMARY_REGION    = var.primary_region
      DR_REGION         = var.dr_region
      VALIDATION_CHECKS = jsonencode(var.validation_checks)
    }
  }

  # The Lambda code would be defined here
}

# API Gateway for validation endpoints
resource "aws_apigatewayv2_api" "validation_api" {
  name          = "${var.project_name}-dr-validation-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "validation_lambda" {
  api_id           = aws_apigatewayv2_api.validation_api.id
  integration_type = "AWS_PROXY"

  integration_uri  = aws_lambda_function.validation.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "validation_route" {
  api_id    = aws_apigatewayv2_api.validation_api.id
  route_key = "POST /validate"

  target = "integrations/${aws_apigatewayv2_integration.validation_lambda.id}"
}

resource "aws_apigatewayv2_stage" "validation_stage" {
  api_id      = aws_apigatewayv2_api.validation_api.id
  name        = "dr-test"
  auto_deploy = true
}

output "validation_endpoints" {
  description = "Endpoints for DR validation checks"
  value = {
    api_endpoint = aws_apigatewayv2_stage.validation_stage.invoke_url
    validate_url = "${aws_apigatewayv2_stage.validation_stage.invoke_url}/validate"
  }
}