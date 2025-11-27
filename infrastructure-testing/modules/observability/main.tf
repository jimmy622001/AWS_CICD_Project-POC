# Observability Module - Implements AWS X-Ray tracing and CloudWatch insights

# X-Ray sampling rule
resource "aws_xray_sampling_rule" "main_sampling_rule" {
  rule_name      = "${var.project_name}-${var.environment}-main-sampling"
  priority       = 1000
  version        = 1
  reservoir_size = 1
  fixed_rate     = var.xray_sampling_rate
  url_path       = "*"
  host           = "*"
  http_method    = "*"
  service_type   = "*"
  service_name   = "*"

  attributes = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# IAM role for Lambda functions that need X-Ray tracing
resource "aws_iam_role" "xray_role" {
  name = "${var.project_name}-${var.environment}-xray-role"

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

resource "aws_iam_role_policy_attachment" "xray_attachment" {
  role       = aws_iam_role.xray_role.name
  policy_arn = "arn:aws:iam::aws:policy/AWSXRayDaemonWriteAccess"
}

# Lambda function to process X-Ray traces and generate insights
resource "aws_lambda_function" "xray_insights" {
  function_name = "${var.project_name}-${var.environment}-xray-insights"
  handler       = "xray_insights.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/xray_insights.zip" # You'll need to create this ZIP
  role          = aws_iam_role.xray_insights_role.arn
  timeout       = 60

  environment {
    variables = {
      PROJECT_NAME = var.project_name
      ENVIRONMENT  = var.environment
    }
  }
}

# IAM role for X-Ray insights Lambda
resource "aws_iam_role" "xray_insights_role" {
  name = "${var.project_name}-${var.environment}-xray-insights-role"

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

resource "aws_iam_role_policy" "xray_insights_policy" {
  name = "${var.project_name}-${var.environment}-xray-insights-policy"
  role = aws_iam_role.xray_insights_role.id

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
          "xray:GetTraceSummaries",
          "xray:BatchGetTraces",
          "xray:GetServiceGraph"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Dashboard for X-Ray insights
resource "aws_cloudwatch_dashboard" "xray_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-xray-dashboard"
  
  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "text"
        width  = 24
        height = 2
        properties = {
          markdown = "# ${var.project_name} ${var.environment} X-Ray Insights Dashboard"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/XRay", "ThrottledCount", { "stat": "Sum" }],
            ["AWS/XRay", "ErrorCount", { "stat": "Sum" }]
          ]
          period = 300
          region = var.region
          title  = "X-Ray Errors and Throttles"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["AWS/XRay", "SegmentSize", { "stat": "Sum" }],
            ["AWS/XRay", "SegmentCount", { "stat": "Sum" }]
          ]
          period = 300
          region = var.region
          title  = "X-Ray Segment Metrics"
        }
      }
    ]
  })
}

# Schedule the X-Ray insights Lambda to run daily
resource "aws_cloudwatch_event_rule" "xray_insights_schedule" {
  name                = "${var.project_name}-${var.environment}-xray-insights-schedule"
  description         = "Schedule for X-Ray insights processing"
  schedule_expression = "rate(1 day)"
}

resource "aws_cloudwatch_event_target" "xray_insights_target" {
  rule      = aws_cloudwatch_event_rule.xray_insights_schedule.name
  target_id = "ProcessXRayInsights"
  arn       = aws_lambda_function.xray_insights.arn
}

resource "aws_lambda_permission" "allow_eventbridge_xray_insights" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.xray_insights.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.xray_insights_schedule.arn
}