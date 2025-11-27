output "trusted_advisor_refresh_function" {
  description = "ARN of the Trusted Advisor refresh Lambda function"
  value       = aws_lambda_function.trusted_advisor_refresh.arn
}

output "process_trusted_advisor_function" {
  description = "ARN of the Trusted Advisor processing Lambda function"
  value       = aws_lambda_function.process_trusted_advisor.arn
}

output "well_architected_review_function" {
  description = "ARN of the Well-Architected review Lambda function"
  value       = aws_lambda_function.well_architected_review.arn
}

output "outputs" {
  description = "All outputs for module integration"
  value = {
    trusted_advisor_refresh_function = aws_lambda_function.trusted_advisor_refresh.function_name
    process_trusted_advisor_function = aws_lambda_function.process_trusted_advisor.function_name
    well_architected_review_function = aws_lambda_function.well_architected_review.function_name
  }
}

output "config" {
  description = "Configuration for the architecture validation module"
  value = {
    report_bucket = var.report_bucket
    environment   = var.environment
  }
}