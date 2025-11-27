# Architecture Validation Module - Implements AWS Trusted Advisor checks and Well-Architected Framework reviews

# IAM role for Lambda to run Trusted Advisor checks
resource "aws_iam_role" "trusted_advisor_role" {
  name = "${var.project_name}-${var.environment}-trusted-advisor-role"

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

resource "aws_iam_role_policy" "trusted_advisor_policy" {
  name = "${var.project_name}-${var.environment}-trusted-advisor-policy"
  role = aws_iam_role.trusted_advisor_role.id

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
          "trustedadvisor:Describe*",
          "trustedadvisor:RefreshCheck"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.report_bucket}/*"
      }
    ]
  })
}

# Lambda function to refresh and check Trusted Advisor
resource "aws_lambda_function" "trusted_advisor_refresh" {
  function_name = "${var.project_name}-${var.environment}-trusted-advisor-refresh"
  handler       = "trusted_advisor_refresh.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/trusted_advisor_refresh.zip" # You'll need to create this ZIP
  role          = aws_iam_role.trusted_advisor_role.arn
  timeout       = 60

  environment {
    variables = {
      REPORT_BUCKET = var.report_bucket
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
    }
  }
}

# Schedule Trusted Advisor checks
resource "aws_cloudwatch_event_rule" "trusted_advisor_schedule" {
  name                = "${var.project_name}-${var.environment}-trusted-advisor-schedule"
  description         = "Schedule for Trusted Advisor checks"
  schedule_expression = var.trusted_advisor_schedule
}

resource "aws_cloudwatch_event_target" "trusted_advisor_refresh_target" {
  rule      = aws_cloudwatch_event_rule.trusted_advisor_schedule.name
  target_id = "RefreshTrustedAdvisor"
  arn       = aws_lambda_function.trusted_advisor_refresh.arn
}

resource "aws_lambda_permission" "allow_eventbridge_trusted_advisor" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.trusted_advisor_refresh.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trusted_advisor_schedule.arn
}

# Lambda to process Trusted Advisor results
resource "aws_lambda_function" "process_trusted_advisor" {
  function_name = "${var.project_name}-${var.environment}-process-trusted-advisor"
  handler       = "process_trusted_advisor.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/process_trusted_advisor.zip" # You'll need to create this ZIP
  role          = aws_iam_role.trusted_advisor_role.arn
  timeout       = 120

  environment {
    variables = {
      REPORT_BUCKET = var.report_bucket
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
    }
  }
}

# EventBridge rule to process Trusted Advisor results after refresh
resource "aws_cloudwatch_event_rule" "trusted_advisor_refreshed" {
  name        = "${var.project_name}-${var.environment}-trusted-advisor-refreshed"
  description = "Capture Trusted Advisor refresh completions"

  event_pattern = jsonencode({
    source      = ["aws.trustedadvisor"]
    detail-type = ["Trusted Advisor Check Item Refresh Notification"]
  })
}

resource "aws_cloudwatch_event_target" "trusted_advisor_process_target" {
  rule      = aws_cloudwatch_event_rule.trusted_advisor_refreshed.name
  target_id = "ProcessTrustedAdvisor"
  arn       = aws_lambda_function.process_trusted_advisor.arn
}

resource "aws_lambda_permission" "allow_eventbridge_trusted_advisor_process" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_trusted_advisor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.trusted_advisor_refreshed.arn
}

# Lambda for Well-Architected review - this would integrate with the Well-Architected Tool API
resource "aws_lambda_function" "well_architected_review" {
  function_name = "${var.project_name}-${var.environment}-well-architected-review"
  handler       = "well_architected_review.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/well_architected_review.zip" # You'll need to create this ZIP
  role          = aws_iam_role.well_architected_role.arn
  timeout       = 120

  environment {
    variables = {
      REPORT_BUCKET = var.report_bucket
      PROJECT_NAME  = var.project_name
      ENVIRONMENT   = var.environment
    }
  }
}

# IAM role for Well-Architected review
resource "aws_iam_role" "well_architected_role" {
  name = "${var.project_name}-${var.environment}-well-architected-role"

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

resource "aws_iam_role_policy" "well_architected_policy" {
  name = "${var.project_name}-${var.environment}-well-architected-policy"
  role = aws_iam_role.well_architected_role.id

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
          "wellarchitected:*"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.report_bucket}/*"
      }
    ]
  })
}

# Schedule Well-Architected reviews
resource "aws_cloudwatch_event_rule" "well_architected_schedule" {
  name                = "${var.project_name}-${var.environment}-well-architected-schedule"
  description         = "Schedule for Well-Architected reviews"
  schedule_expression = var.trusted_advisor_schedule # Using the same schedule as Trusted Advisor
}

resource "aws_cloudwatch_event_target" "well_architected_target" {
  rule      = aws_cloudwatch_event_rule.well_architected_schedule.name
  target_id = "RunWellArchitectedReview"
  arn       = aws_lambda_function.well_architected_review.arn
}

resource "aws_lambda_permission" "allow_eventbridge_well_architected" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.well_architected_review.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.well_architected_schedule.arn
}