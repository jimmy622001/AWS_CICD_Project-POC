resource "aws_lambda_function" "failover_test" {
  function_name = "scheduled-failover-test-${var.environment}"
  description   = "Lambda function to test DR failover monthly during off-peak hours"
  filename      = "${path.module}/lambda_package.zip"
  handler       = "failover_test.lambda_handler"
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.9"
  timeout       = 300 # 5 minutes should be enough for testing
  memory_size   = 256

  environment {
    variables = {
      PRIMARY_REGION         = var.primary_region
      DR_REGION              = var.dr_region
      DOMAIN_NAME            = var.domain_name
      HEALTH_CHECK_PATH      = var.health_check_path
      ROUTE53_HOSTED_ZONE_ID = var.hosted_zone_id
      PRIMARY_ENDPOINT       = var.primary_endpoint
      DR_ENDPOINT            = var.dr_endpoint
      SNS_TOPIC_ARN          = aws_sns_topic.failover_test_notification.arn
    }
  }

  depends_on = [
    aws_cloudwatch_log_group.lambda_logs,
  ]

  # This assumes you'll package the Lambda function locally
  # In a real setup, you might want to use a more sophisticated approach
  # like using a zip archive from S3 or using the archive provider
  lifecycle {
    ignore_changes = [filename]
  }
}

# Create a log group for the Lambda function
resource "aws_cloudwatch_log_group" "lambda_logs" {
  name              = "/aws/lambda/scheduled-failover-test-${var.environment}"
  retention_in_days = 14
}

# IAM role for the Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "scheduled-failover-test-role-${var.environment}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# IAM policy for the Lambda function
resource "aws_iam_policy" "lambda_policy" {
  name        = "scheduled-failover-test-policy-${var.environment}"
  description = "Policy for the scheduled failover test Lambda function"

  policy = file("${path.module}/iam_policy.json")
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_policy.arn
}

# CloudWatch Events Rule to schedule the Lambda execution
resource "aws_cloudwatch_event_rule" "monthly_schedule" {
  name                = "scheduled-failover-test-${var.environment}"
  description         = "Trigger failover test on the first Saturday of each month at 2:00 AM"
  schedule_expression = "cron(0 2 ? * 7#1 *)" # First Saturday of each month at 2:00 AM
}

# Target for the CloudWatch Events Rule
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.monthly_schedule.name
  target_id = "failover_test"
  arn       = aws_lambda_function.failover_test.arn
}

# Permission for CloudWatch Events to invoke the Lambda function
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.failover_test.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monthly_schedule.arn
}

# SNS Topic for notifications
resource "aws_sns_topic" "failover_test_notification" {
  name = "failover-test-notifications-${var.environment}"
}

# SNS Topic Policy
resource "aws_sns_topic_policy" "default" {
  arn    = aws_sns_topic.failover_test_notification.arn
  policy = data.aws_iam_policy_document.sns_topic_policy.json
}

# IAM Policy Document for SNS Topic
data "aws_iam_policy_document" "sns_topic_policy" {
  statement {
    effect  = "Allow"
    actions = ["SNS:Publish"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    resources = [aws_sns_topic.failover_test_notification.arn]
  }
}

# Subscribe email addresses to the SNS topic
resource "aws_sns_topic_subscription" "email_subscriptions" {
  for_each  = toset(var.notification_emails)
  topic_arn = aws_sns_topic.failover_test_notification.arn
  protocol  = "email"
  endpoint  = each.value
}

# CloudWatch Alarm if the Lambda function fails
resource "aws_cloudwatch_metric_alarm" "lambda_error_alarm" {
  alarm_name          = "failover-test-error-${var.environment}"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "1"
  alarm_description   = "This alarm monitors for errors in the scheduled failover test Lambda function"
  alarm_actions       = [aws_sns_topic.failover_test_notification.arn]
  dimensions = {
    FunctionName = aws_lambda_function.failover_test.function_name
  }
}

# Null resource to create the Lambda package (would be replaced with a better solution in production)
resource "null_resource" "lambda_package" {
  provisioner "local-exec" {
    command = <<EOT
      cd ${path.module} && \
      zip -r lambda_package.zip failover_test.py
    EOT
  }

  triggers = {
    source_code_hash = filemd5("${path.module}/failover_test.py")
  }
}