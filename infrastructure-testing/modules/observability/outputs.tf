output "sampling_rule_arn" {
  description = "ARN of the X-Ray sampling rule"
  value       = aws_xray_sampling_rule.main_sampling_rule.arn
}

output "xray_role_arn" {
  description = "ARN of the IAM role for X-Ray tracing"
  value       = aws_iam_role.xray_role.arn
}

output "xray_dashboard_name" {
  description = "Name of the CloudWatch dashboard for X-Ray insights"
  value       = aws_cloudwatch_dashboard.xray_dashboard.dashboard_name
}

output "outputs" {
  description = "All outputs for module integration"
  value = {
    sampling_rule_arn = aws_xray_sampling_rule.main_sampling_rule.arn
    xray_role_arn     = aws_iam_role.xray_role.arn
    dashboard_name    = aws_cloudwatch_dashboard.xray_dashboard.dashboard_name
    insights_function = aws_lambda_function.xray_insights.function_name
  }
}

output "config" {
  description = "Configuration for the observability module"
  value = {
    xray_sampling_rate = var.xray_sampling_rate
    environment        = var.environment
  }
}