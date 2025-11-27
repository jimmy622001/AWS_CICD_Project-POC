variable "project" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, prod, dr)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "artifact_bucket_arn" {
  description = "ARN of the S3 bucket for artifacts"
  type        = string
}

variable "artifact_bucket_name" {
  description = "Name of the S3 bucket for artifacts"
  type        = string
}

variable "kms_key_arn" {
  description = "ARN of the KMS key for encryption"
  type        = string
}

variable "infrastructure_repository_name" {
  description = "Name of the CodeCommit repository for infrastructure code"
  type        = string
}

variable "eks_repository_name" {
  description = "Name of the CodeCommit repository for EKS code"
  type        = string
}

variable "app_repository_name" {
  description = "Name of the CodeCommit repository for application code"
  type        = string
}

variable "pre_deployment_validation_project_name" {
  description = "Name of the CodeBuild project for pre-deployment validation"
  type        = string
}

variable "infrastructure_build_project_name" {
  description = "Name of the CodeBuild project for infrastructure"
  type        = string
}

variable "eks_build_project_name" {
  description = "Name of the CodeBuild project for EKS"
  type        = string
}

variable "app_build_project_name" {
  description = "Name of the CodeBuild project for the application"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}