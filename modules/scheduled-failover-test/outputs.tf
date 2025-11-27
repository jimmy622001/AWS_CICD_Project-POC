output "lambda_function_name" {
  description = "Name of the created Lambda function for failover testing"
  value       = aws_lambda_function.failover_test.function_name
}

output "lambda_function_arn" {
  description = "ARN of the created Lambda function for failover testing"
  value       = aws_lambda_function.failover_test.arn
}

output "schedule_expression" {
  description = "The schedule expression for when failover tests will run"
  value       = aws_cloudwatch_event_rule.monthly_schedule.schedule_expression
}

output "notification_topic_arn" {
  description = "ARN of the SNS topic for failover test notifications"
  value       = aws_sns_topic.failover_test_notification.arn
}