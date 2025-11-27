output "canary_names" {
  description = "Names of the created canaries"
  value       = [for canary in aws_synthetics_canary.api_canaries : canary.name]
}

output "canary_dashboard_name" {
  description = "Name of the CloudWatch dashboard for canaries"
  value       = aws_cloudwatch_dashboard.canary_dashboard.dashboard_name
}

output "outputs" {
  description = "All outputs for module integration"
  value = {
    canary_names       = [for canary in aws_synthetics_canary.api_canaries : canary.name]
    dashboard_name     = aws_cloudwatch_dashboard.canary_dashboard.dashboard_name
    processor_function = aws_lambda_function.process_canary_results.function_name
  }
}

output "config" {
  description = "Configuration for the functionality testing module"
  value = {
    endpoints          = var.api_endpoints
    code_bucket        = var.code_bucket
    environment        = var.environment
  }
}