output "pre_deployment_validation_project_arn" {
  description = "ARN of the pre-deployment validation build project"
  value       = aws_codebuild_project.pre_deployment_validation.arn
}

output "pre_deployment_validation_project_name" {
  description = "Name of the pre-deployment validation build project"
  value       = aws_codebuild_project.pre_deployment_validation.name
}

output "infrastructure_build_project_arn" {
  description = "ARN of the infrastructure build project"
  value       = aws_codebuild_project.infrastructure_build.arn
}

output "eks_build_project_arn" {
  description = "ARN of the EKS build project"
  value       = aws_codebuild_project.eks_build.arn
}

output "app_build_project_arn" {
  description = "ARN of the application build project"
  value       = aws_codebuild_project.app_build.arn
}

output "codebuild_role_arn" {
  description = "ARN of the CodeBuild service role"
  value       = aws_iam_role.codebuild_role.arn
}

output "ecr_repository_url" {
  description = "URL of the ECR repository"
  value       = aws_ecr_repository.app_repository.repository_url
}

output "ecr_repository_arn" {
  description = "ARN of the ECR repository"
  value       = aws_ecr_repository.app_repository.arn
}