provider "aws" {
  region = "eu-west-1"
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Variables
variable "project" {
  description = "Project name"
  type        = string
  default     = "aws-cicd"
}

variable "environments" {
  description = "List of environments"
  type        = list(string)
  default     = ["dev", "prod", "dr"]
}

variable "artifact_bucket_name" {
  description = "S3 bucket name for pipeline artifacts"
  type        = string
  default     = "aws-cicd-artifacts"
}

variable "kms_key_alias" {
  description = "Alias for the KMS key used to encrypt artifacts"
  type        = string
  default     = "alias/aws-cicd-key"
}

# KMS Key for encryption
resource "aws_kms_key" "cicd_key" {
  description             = "KMS key for CICD artifacts"
  deletion_window_in_days = 10
  enable_key_rotation     = true

  tags = {
    Name    = "${var.project}-kms-key"
    Project = var.project
  }
}

resource "aws_kms_alias" "cicd_key_alias" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.cicd_key.key_id
}

# S3 bucket for artifacts
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket_name

  tags = {
    Name    = "${var.project}-artifacts"
    Project = var.project
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts_encryption" {
  bucket = aws_s3_bucket.artifacts.bucket

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.cicd_key.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

# Output the S3 bucket name
output "artifact_bucket_name" {
  value = aws_s3_bucket.artifacts.bucket
}

# Output the KMS key ARN
output "kms_key_arn" {
  value = aws_kms_key.cicd_key.arn
}