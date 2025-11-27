provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}

# Configure remote state if needed
terraform {
  backend "s3" {
    # Configure your backend settings
  }
}

locals {
  is_dev = var.environment == "dev"
}

# Security Testing Module
module "security_testing" {
  source = "./modules/security_testing"

  project_name              = var.project_name
  environment               = var.environment
  region                    = var.region
  account_id                = var.account_id
  vpc_id                    = var.vpc_id
  inspector_schedule        = var.inspector_schedule
  enable_security_hub       = var.enable_security_hub
  enable_guardduty          = var.enable_guardduty
  security_report_bucket    = aws_s3_bucket.test_artifacts.bucket
  notification_email        = var.notification_email
}

# Functionality Testing Module
module "functionality_testing" {
  source = "./modules/functionality_testing"

  project_name         = var.project_name
  environment          = var.environment
  region               = var.region
  api_endpoints        = var.api_endpoints
  code_bucket          = aws_s3_bucket.test_artifacts.bucket
  canary_schedule      = var.canary_schedule
}

# Architecture Validation Module
module "architecture_validation" {
  source = "./modules/architecture_validation"

  project_name              = var.project_name
  environment               = var.environment
  region                    = var.region
  trusted_advisor_schedule  = var.trusted_advisor_schedule
  report_bucket             = aws_s3_bucket.test_artifacts.bucket
}

# Observability Module (including X-Ray)
module "observability" {
  source = "./modules/observability"

  project_name      = var.project_name
  environment       = var.environment
  region            = var.region
  xray_sampling_rate = var.xray_sampling_rate
}

# Reporting Module
module "reporting" {
  source = "./modules/reporting"

  project_name      = var.project_name
  environment       = var.environment
  region            = var.region
  reports_bucket    = aws_s3_bucket.test_artifacts.bucket
  notification_email = var.notification_email
}

# Central S3 bucket for test artifacts and reports
resource "aws_s3_bucket" "test_artifacts" {
  bucket = "${var.project_name}-${var.environment}-test-artifacts"
}

resource "aws_s3_bucket_lifecycle_configuration" "test_artifacts_lifecycle" {
  bucket = aws_s3_bucket.test_artifacts.id

  rule {
    id     = "cleanup-old-reports"
    status = "Enabled"

    expiration {
      days = 90
    }
  }
}

# Test orchestration Lambda
resource "aws_lambda_function" "test_orchestrator" {
  function_name = "${var.project_name}-${var.environment}-test-orchestrator"
  handler       = "orchestrator.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/test_orchestrator.zip"
  role          = aws_iam_role.test_orchestrator_role.arn
  timeout       = 300
  
  environment {
    variables = {
      SECURITY_TESTING_CONFIG    = jsonencode(module.security_testing.config)
      FUNCTIONALITY_TESTING_CONFIG = jsonencode(module.functionality_testing.config)
      ARCHITECTURE_VALIDATION_CONFIG = jsonencode(module.architecture_validation.config)
      OBSERVABILITY_CONFIG       = jsonencode(module.observability.config)
      REPORTING_CONFIG           = jsonencode(module.reporting.config)
      ENVIRONMENT                = var.environment
      TEST_ARTIFACTS_BUCKET      = aws_s3_bucket.test_artifacts.bucket
    }
  }
}

# IAM Role for test orchestrator
resource "aws_iam_role" "test_orchestrator_role" {
  name = "${var.project_name}-${var.environment}-test-orchestrator-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "test_orchestrator_policy" {
  name = "${var.project_name}-${var.environment}-test-orchestrator-policy"
  role = aws_iam_role.test_orchestrator_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "inspector:*",
          "cloudwatch:*",
          "synthetics:*",
          "xray:*",
          "s3:*",
          "lambda:InvokeFunction"
        ]
        Resource = "*"
      }
    ]
  })
}

# Schedule regular testing in dev environment
resource "aws_cloudwatch_event_rule" "regular_testing" {
  count               = local.is_dev ? 1 : 0
  name                = "${var.project_name}-${var.environment}-regular-testing"
  description         = "Triggers regular testing in dev environment"
  schedule_expression = var.testing_schedule
}

resource "aws_cloudwatch_event_target" "test_orchestrator" {
  count     = local.is_dev ? 1 : 0
  rule      = aws_cloudwatch_event_rule.regular_testing[0].name
  target_id = "TestOrchestrator"
  arn       = aws_lambda_function.test_orchestrator.arn
}

resource "aws_lambda_permission" "allow_cloudwatch" {
  count         = local.is_dev ? 1 : 0
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.test_orchestrator.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.regular_testing[0].arn
}