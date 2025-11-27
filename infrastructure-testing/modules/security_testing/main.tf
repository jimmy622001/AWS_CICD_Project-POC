# Security Testing Module - Implements AWS Inspector, Security Hub, and GuardDuty

# Create resource group for Inspector assessment
resource "aws_resourcegroups_group" "inspector_group" {
  name = "${var.project_name}-${var.environment}-inspector-group"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::EC2::Instance"]
      TagFilters = [
        {
          Key    = "Environment"
          Values = [var.environment]
        }
      ]
    })
  }
}

# Configure AWS Inspector
resource "aws_inspector_assessment_target" "target" {
  name               = "${var.project_name}-${var.environment}-assessment-target"
  resource_group_arn = aws_resourcegroups_group.inspector_group.arn
}

resource "aws_inspector_assessment_template" "template" {
  name       = "${var.project_name}-${var.environment}-assessment-template"
  target_arn = aws_inspector_assessment_target.target.arn
  duration   = 3600

  rules_package_arns = [
    "arn:aws:inspector:${var.region}:aws:rules-package/common-vulnerabilities-and-exposures",
    "arn:aws:inspector:${var.region}:aws:rules-package/cis-operating-system-security-configuration-benchmarks",
    "arn:aws:inspector:${var.region}:aws:rules-package/network-reachability",
    "arn:aws:inspector:${var.region}:aws:rules-package/security-best-practices"
  ]
}

# Schedule Inspector runs
resource "aws_cloudwatch_event_rule" "inspector_schedule" {
  name                = "${var.project_name}-${var.environment}-inspector-schedule"
  description         = "Schedule for Inspector assessments"
  schedule_expression = var.inspector_schedule
}

resource "aws_cloudwatch_event_target" "start_inspector_assessment" {
  rule      = aws_cloudwatch_event_rule.inspector_schedule.name
  target_id = "StartInspectorAssessment"
  arn       = "arn:aws:inspector:${var.region}:${var.account_id}:target/${aws_inspector_assessment_target.target.id}"
  role_arn  = aws_iam_role.inspector_events_role.arn
}

# IAM role for EventBridge to start Inspector
resource "aws_iam_role" "inspector_events_role" {
  name = "${var.project_name}-${var.environment}-inspector-events-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "events.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "inspector_events_policy" {
  name = "${var.project_name}-${var.environment}-inspector-events-policy"
  role = aws_iam_role.inspector_events_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "inspector:StartAssessmentRun"
        Resource = aws_inspector_assessment_template.template.arn
      }
    ]
  })
}

# Lambda function to process Inspector findings
resource "aws_lambda_function" "process_inspector_findings" {
  function_name = "${var.project_name}-${var.environment}-process-inspector-findings"
  handler       = "process_inspector_findings.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/process_inspector_findings.zip" # You'll need to create this ZIP
  role          = aws_iam_role.inspector_processor_role.arn
  timeout       = 60

  environment {
    variables = {
      REPORT_BUCKET     = var.security_report_bucket
      NOTIFICATION_EMAIL = var.notification_email
      PROJECT_NAME      = var.project_name
      ENVIRONMENT       = var.environment
    }
  }
}

# IAM role for Lambda to process Inspector findings
resource "aws_iam_role" "inspector_processor_role" {
  name = "${var.project_name}-${var.environment}-inspector-processor-role"

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

resource "aws_iam_role_policy" "inspector_processor_policy" {
  name = "${var.project_name}-${var.environment}-inspector-processor-policy"
  role = aws_iam_role.inspector_processor_role.id

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
          "inspector:ListFindings",
          "inspector:DescribeFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.security_report_bucket}/*"
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

# EventBridge rule to trigger Lambda when Inspector findings are available
resource "aws_cloudwatch_event_rule" "inspector_findings" {
  name        = "${var.project_name}-${var.environment}-inspector-findings"
  description = "Capture Inspector findings"

  event_pattern = jsonencode({
    source      = ["aws.inspector"]
    detail-type = ["Inspector Assessment Run Completed"]
    detail = {
      "assessment-template-arn" = [aws_inspector_assessment_template.template.arn]
    }
  })
}

resource "aws_cloudwatch_event_target" "inspector_findings_lambda" {
  rule      = aws_cloudwatch_event_rule.inspector_findings.name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.process_inspector_findings.arn
}

resource "aws_lambda_permission" "allow_eventbridge_inspector" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_inspector_findings.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.inspector_findings.arn
}

# Enable Security Hub if specified
resource "aws_securityhub_account" "security_hub" {
  count = var.enable_security_hub ? 1 : 0
}

# Enable GuardDuty if specified
resource "aws_guardduty_detector" "guardduty" {
  count = var.enable_guardduty ? 1 : 0
  
  enable = true
  finding_publishing_frequency = "SIX_HOURS"
}

# Process GuardDuty findings if enabled
resource "aws_lambda_function" "process_guardduty_findings" {
  count         = var.enable_guardduty ? 1 : 0
  function_name = "${var.project_name}-${var.environment}-process-guardduty-findings"
  handler       = "process_guardduty_findings.handler"
  runtime       = "python3.9"
  filename      = "${path.module}/lambda/process_guardduty_findings.zip" # You'll need to create this ZIP
  role          = aws_iam_role.guardduty_processor_role[0].arn
  timeout       = 60

  environment {
    variables = {
      REPORT_BUCKET     = var.security_report_bucket
      NOTIFICATION_EMAIL = var.notification_email
      PROJECT_NAME      = var.project_name
      ENVIRONMENT       = var.environment
    }
  }
}

# IAM role for Lambda to process GuardDuty findings
resource "aws_iam_role" "guardduty_processor_role" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project_name}-${var.environment}-guardduty-processor-role"

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

resource "aws_iam_role_policy" "guardduty_processor_policy" {
  count = var.enable_guardduty ? 1 : 0
  name  = "${var.project_name}-${var.environment}-guardduty-processor-policy"
  role  = aws_iam_role.guardduty_processor_role[0].id

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
          "guardduty:GetFindings"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject"
        ]
        Resource = "arn:aws:s3:::${var.security_report_bucket}/*"
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

# EventBridge rule for GuardDuty findings
resource "aws_cloudwatch_event_rule" "guardduty_findings" {
  count       = var.enable_guardduty ? 1 : 0
  name        = "${var.project_name}-${var.environment}-guardduty-findings"
  description = "Capture GuardDuty findings"

  event_pattern = jsonencode({
    source      = ["aws.guardduty"]
    detail-type = ["GuardDuty Finding"]
  })
}

resource "aws_cloudwatch_event_target" "guardduty_findings_lambda" {
  count     = var.enable_guardduty ? 1 : 0
  rule      = aws_cloudwatch_event_rule.guardduty_findings[0].name
  target_id = "SendToLambda"
  arn       = aws_lambda_function.process_guardduty_findings[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge_guardduty" {
  count         = var.enable_guardduty ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.process_guardduty_findings[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.guardduty_findings[0].arn
}