output "artifact_bucket_name" {
  description = "S3 bucket for CI/CD artifacts"
  value       = aws_s3_bucket.artifacts.bucket
}

output "kms_key_arn" {
  description = "KMS key ARN for CI/CD artifacts"
  value       = aws_kms_key.cicd_key.arn
}

# These outputs are placeholders for the Route 53 failover module
# You'll need to adjust these based on your actual infrastructure
output "endpoint_dns" {
  description = "The DNS endpoint for the application (e.g., load balancer or CloudFront)"
  value       = var.application_endpoint != "" ? var.application_endpoint : "placeholder-endpoint.${var.aws_region}.amazonaws.com"
}

output "zone_id" {
  description = "The hosted zone ID for the application endpoint"
  value       = var.hosted_zone_id != "" ? var.hosted_zone_id : "Z123456789EXAMPLE"
}
