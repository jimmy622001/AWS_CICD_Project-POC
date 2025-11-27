output "report_generator_arn" {
  description = "ARN of the report generator Lambda function"
  value       = aws_lambda_function.generate_report.arn
}

output "sns_topic_arn" {
  description = "ARN of the SNS topic for report notifications"
  value       = aws_sns_topic.report_notifications.arn
}

output "outputs" {
  description = "All outputs for module integration"
  value = {
    report_generator_function = aws_lambda_function.generate_report.function_name
    report_notifier_function  = aws_lambda_function.notify_report_available.function_name
    sns_topic_arn             = aws_sns_topic.report_notifications.arn
  }
}

output "config" {
  description = "Configuration for the reporting module"
  value = {
    reports_bucket     = var.reports_bucket
    notification_email = var.notification_email
    environment        = var.environment
  }
}