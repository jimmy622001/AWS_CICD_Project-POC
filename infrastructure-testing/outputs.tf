output "test_artifacts_bucket" {
  description = "S3 bucket for test artifacts"
  value       = aws_s3_bucket.test_artifacts.bucket
}

output "security_testing_results" {
  description = "Security testing outputs"
  value       = module.security_testing.outputs
}

output "functionality_testing_results" {
  description = "Functionality testing outputs"
  value       = module.functionality_testing.outputs
}

output "architecture_validation_results" {
  description = "Architecture validation outputs"
  value       = module.architecture_validation.outputs
}

output "observability_config" {
  description = "Observability configuration"
  value       = module.observability.outputs
}

output "test_orchestrator_function" {
  description = "ARN of the test orchestrator Lambda function"
  value       = aws_lambda_function.test_orchestrator.arn
}