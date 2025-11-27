provider "aws" {
  region = var.aws_region
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

# Use variables from variables.tf

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

# Outputs are defined in outputs.tf