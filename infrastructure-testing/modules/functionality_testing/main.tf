# Functionality Testing Module - Implements CloudWatch Synthetics Canaries

# Create IAM role for Synthetics Canary
resource "aws_iam_role" "canary_role" {
  name = "${var.project_name}-${var.environment}-canary-role"

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

resource "aws_iam_role_policy" "canary_policy" {
  name = "${var.project_name}-${var.environment}-canary-policy"
  role = aws_iam_role.canary_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.code_bucket}/*",
          "arn:aws:s3:::${var.code_bucket}"
        ]
      },
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
          "cloudwatch:PutMetricData"
        ]
        Resource = "*"
        Condition = {
          StringEquals = {
            "cloudwatch:namespace" = "CloudWatchSynthetics"
          }
        }
      }
    ]
  })
}

# Create a canary for each API endpoint
resource "aws_synthetics_canary" "api_canaries" {
  for_each = { for idx, endpoint in var.api_endpoints : endpoint.name => endpoint }

  name                 = "${var.project_name}-${var.environment}-${each.value.name}-canary"
  artifact_s3_location = "s3://${var.code_bucket}/canary-artifacts/"
  execution_role_arn   = aws_iam_role.canary_role.arn
  runtime_version      = "syn-nodejs-puppeteer-3.9"
  
  schedule {
    expression = var.canary_schedule
  }

  # This is a placeholder - you'll need to create and upload the actual canary script
  code {
    handler  = "apiCanary.handler"
    s3_bucket = var.code_bucket
    s3_key    = "canary-code/api_canary.zip"
  }

  run_config {
    timeout_in_seconds = 60
    environment_variables = {
      API_ENDPOINT       = each.value.url
      HTTP_METHOD        = each.value.method
      EXPECTED_STATUS    = tostring(each.value.expected_status_code)
      PROJECT_NAME       = var.project_name
      ENVIRONMENT        = var.environment
    }
  }

  depends_on = [aws_s3_object.canary_code]
}

# Upload a placeholder canary code (you'll need to replace this with real code)
resource "aws_s3_object" "canary_code" {
  bucket  = var.code_bucket
  key     = "canary-code/api_canary.zip"
  source  = "${path.module}/scripts/api_canary.zip" # You'll need to create this ZIP
  etag    = filemd5("${path.module}/scripts/api_canary.zip")
}

# Create CloudWatch Dashboard for canaries
resource "aws_cloudwatch_dashboard" "canary_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-functionality-dashboard"
  
  dashboard_body = jsonencode({
    widgets = concat([
      {
        type   = "text"
        width  = 24
        height = 2
        properties = {
          markdown = "# ${var.project_name} ${var.environment} API Testing Dashboard"
        }
      }
    ], 
    [for endpoint in var.api_endpoints : 
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          metrics = [
            ["CloudWatchSynthetics", "SuccessPercent", "CanaryName", "${var.project_name}-${var.environment}-${endpoint.name}-canary"],
            ["CloudWatchSynthetics", "Duration", "CanaryName", "${var.project_name}-${var.environment}-${endpoint.name}-canary"]
          ]
          period = 300
          stat   = "Average"
          region = var.region
          title  = "${endpoint.name} API Status"
        }
      }
    ])
  })
}

# Create Lambda function to process canary results
resource "aws_lambda_function" "process_canary_results" {
  function_name = "${var.project_name}-${var.environment}-process-canary-results"
  handler       = "process_canary_results.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/process_canary_results.zip" # You'll need to create this ZIP
  role          = aws_iam_role.canary_processor_role.arn
  timeout       = 60

  environment {
    variables = {
      CODE_BUCKET  = var.code_bucket
      PROJECT_NAME = var.project_name
      ENVIRONMENT  = var.environment
    }
  }
}

# IAM role for Lambda to process canary results
resource "aws_iam_role" "canary_processor_role" {
  name = "${var.project_name}-${var.environment}-canary-processor-role"

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

resource "aws_iam_role_policy" "canary_processor_policy" {
  name = "${var.project_name}-${var.environment}-canary-processor-policy"
  role = aws_iam_role.canary_processor_role.id

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
          "synthetics:DescribeCanaries",
          "synthetics:DescribeCanariesLastRun",
          "synthetics:GetCanaryRuns"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.code_bucket}/*",
          "arn:aws:s3:::${var.code_bucket}"
        ]
      }
    ]
  })
}

# Create EventBridge rule to trigger Lambda when canary runs complete
resource "aws_cloudwatch_event_rule" "canary_run_completed" {
  name        = "${var.project_name}-${var.environment}-canary-run-completed"
  description = "Capture canary run completions"

  event_pattern = jsonencode({
    source      = ["aws.synthetics"]
    detail-type = ["Synthetics Canary Run Completed"]
  })
}

resource "aws_cloudwatch_event_target" "canary_run_lambda" {
  rule      = aws_cloudwatch_event_rule.canary_run_completed.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.process_canary_results.arn
}

resource "aws_lambda_permission" "allow_eventbridge_canary" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_canary_results.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.canary_run_completed.arn
}