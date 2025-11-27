# Reporting Module - Aggregates test results and generates comprehensive reports

# Lambda function to generate consolidated reports
resource "aws_lambda_function" "generate_report" {
  function_name = "${var.project_name}-${var.environment}-report-generator"
  handler       = "report_generator.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/report_generator.zip" # You'll need to create this ZIP
  role          = aws_iam_role.report_generator_role.arn
  timeout       = 300
  memory_size   = 512

  environment {
    variables = {
      REPORTS_BUCKET     = var.reports_bucket
      NOTIFICATION_EMAIL = var.notification_email
      PROJECT_NAME       = var.project_name
      ENVIRONMENT        = var.environment
    }
  }
}

# IAM role for report generator Lambda
resource "aws_iam_role" "report_generator_role" {
  name = "${var.project_name}-${var.environment}-report-generator-role"

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

resource "aws_iam_role_policy" "report_generator_policy" {
  name = "${var.project_name}-${var.environment}-report-generator-policy"
  role = aws_iam_role.report_generator_role.id

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
          "s3:GetObject",
          "s3:ListBucket",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.reports_bucket}",
          "arn:aws:s3:::${var.reports_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ses:SendEmail"
        ]
        Resource = "*"
      }
    ]
  })
}

# Schedule weekly comprehensive reports
resource "aws_cloudwatch_event_rule" "weekly_report" {
  name                = "${var.project_name}-${var.environment}-weekly-report"
  description         = "Generate weekly comprehensive reports"
  schedule_expression = "cron(0 8 ? * MON *)" # Monday at 8 AM
}

resource "aws_cloudwatch_event_target" "weekly_report_target" {
  rule      = aws_cloudwatch_event_rule.weekly_report.name
  target_id = "GenerateReport"
  arn       = aws_lambda_function.generate_report.arn
  
  input = jsonencode({
    reportType = "weekly"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_weekly_report" {
  statement_id  = "AllowExecutionFromEventBridgeWeekly"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_report.arn
}

# Schedule monthly comprehensive reports
resource "aws_cloudwatch_event_rule" "monthly_report" {
  name                = "${var.project_name}-${var.environment}-monthly-report"
  description         = "Generate monthly comprehensive reports"
  schedule_expression = "cron(0 8 1 * ? *)" # 1st of each month at 8 AM
}

resource "aws_cloudwatch_event_target" "monthly_report_target" {
  rule      = aws_cloudwatch_event_rule.monthly_report.name
  target_id = "GenerateReport"
  arn       = aws_lambda_function.generate_report.arn
  
  input = jsonencode({
    reportType = "monthly"
  })
}

resource "aws_lambda_permission" "allow_eventbridge_monthly_report" {
  statement_id  = "AllowExecutionFromEventBridgeMonthly"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.generate_report.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_report.arn
}

# Create an SNS topic for report notifications
resource "aws_sns_topic" "report_notifications" {
  name = "${var.project_name}-${var.environment}-report-notifications"
}

resource "aws_sns_topic_subscription" "email_subscription" {
  topic_arn = aws_sns_topic.report_notifications.arn
  protocol  = "email"
  endpoint  = var.notification_email
}

# Lambda to send report notifications to SNS
resource "aws_lambda_function" "notify_report_available" {
  function_name = "${var.project_name}-${var.environment}-report-notifier"
  handler       = "report_notifier.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/report_notifier.zip" # You'll need to create this ZIP
  role          = aws_iam_role.report_notifier_role.arn
  timeout       = 30

  environment {
    variables = {
      SNS_TOPIC_ARN     = aws_sns_topic.report_notifications.arn
      PROJECT_NAME      = var.project_name
      ENVIRONMENT       = var.environment
    }
  }
}

# IAM role for report notifier Lambda
resource "aws_iam_role" "report_notifier_role" {
  name = "${var.project_name}-${var.environment}-report-notifier-role"

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

resource "aws_iam_role_policy" "report_notifier_policy" {
  name = "${var.project_name}-${var.environment}-report-notifier-policy"
  role = aws_iam_role.report_notifier_role.id

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
          "sns:Publish"
        ]
        Resource = aws_sns_topic.report_notifications.arn
      }
    ]
  })
}

# S3 event notification to trigger the notifier Lambda when a report is created
resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = var.reports_bucket

  lambda_function {
    lambda_function_arn = aws_lambda_function.notify_report_available.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "reports/"
    filter_suffix       = ".pdf"
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.notify_report_available.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.reports_bucket}"
}