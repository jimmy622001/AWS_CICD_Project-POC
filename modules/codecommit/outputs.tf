output "infra_repository_clone_url_http" {
  description = "HTTPS clone URL of the infrastructure repository"
  value       = aws_codecommit_repository.infra_repository.clone_url_http
}

output "infra_repository_clone_url_ssh" {
  description = "SSH clone URL of the infrastructure repository"
  value       = aws_codecommit_repository.infra_repository.clone_url_ssh
}

output "infra_repository_arn" {
  description = "ARN of the infrastructure repository"
  value       = aws_codecommit_repository.infra_repository.arn
}

output "eks_repository_clone_url_http" {
  description = "HTTPS clone URL of the EKS repository"
  value       = aws_codecommit_repository.eks_repository.clone_url_http
}

output "eks_repository_clone_url_ssh" {
  description = "SSH clone URL of the EKS repository"
  value       = aws_codecommit_repository.eks_repository.clone_url_ssh
}

output "eks_repository_arn" {
  description = "ARN of the EKS repository"
  value       = aws_codecommit_repository.eks_repository.arn
}

output "app_repository_clone_url_http" {
  description = "HTTPS clone URL of the application repository"
  value       = aws_codecommit_repository.app_repository.clone_url_http
}

output "app_repository_clone_url_ssh" {
  description = "SSH clone URL of the application repository"
  value       = aws_codecommit_repository.app_repository.clone_url_ssh
}

output "app_repository_arn" {
  description = "ARN of the application repository"
  value       = aws_codecommit_repository.app_repository.arn
}

output "trigger_role_arn" {
  description = "ARN of the CodeCommit trigger role"
  value       = aws_iam_role.codecommit_trigger_role.arn
}