output "infrastructure_pipeline_arn" {
  description = "ARN of the infrastructure pipeline"
  value       = aws_codepipeline.infrastructure_pipeline.arn
}

output "eks_pipeline_arn" {
  description = "ARN of the EKS pipeline"
  value       = aws_codepipeline.eks_pipeline.arn
}

output "app_pipeline_arn" {
  description = "ARN of the application pipeline"
  value       = aws_codepipeline.app_pipeline.arn
}

output "codepipeline_role_arn" {
  description = "ARN of the CodePipeline service role"
  value       = aws_iam_role.codepipeline_role.arn
}

output "pipeline_approval_topic_arn" {
  description = "ARN of the SNS topic for pipeline approvals"
  value       = aws_sns_topic.pipeline_approval.arn
}