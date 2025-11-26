# Required providers for this module
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      configuration_aliases = [ aws.primary, aws.dr ]
    }
  }
}

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

variable "test_timeout_minutes" {
  description = "Timeout for DR tests in minutes"
  type        = number
  default     = 30
}

variable "rto_threshold_minutes" {
  description = "Recovery Time Objective threshold in minutes"
  type        = number
  default     = 15
}

variable "rpo_threshold_minutes" {
  description = "Recovery Point Objective threshold in minutes"
  type        = number
  default     = 60
}

variable "notification_email" {
  description = "Email address for test notifications"
  type        = string
}

variable "fis_experiments" {
  description = "List of AWS FIS experiments to run"
  type        = list(string)
  default     = []  
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
  # Placeholder for actual Lambda code
  filename         = "${path.module}/lambda/function.zip"
  source_code_hash = filebase64sha256("${path.module}/lambda/function.zip")
}

# IAM role for the Lambda function
resource "aws_iam_role" "validation_lambda_role" {
  name = "${var.project_name}-validation-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      },
    ]
  })
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