# Required providers for this module
terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.primary, aws.dr]
    }
  }
}

variable "project_name" {
  description = "Name of the project being tested"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
}

variable "vpc_cidr_primary" {
  description = "CIDR block for the primary VPC"
  type        = string
}

variable "vpc_cidr_dr" {
  description = "CIDR block for the DR VPC"
  type        = string
}

variable "subnets_primary" {
  description = "List of subnet CIDR blocks for the primary region"
  type        = list(string)
}

variable "subnets_dr" {
  description = "List of subnet CIDR blocks for the DR region"
  type        = list(string)
}

variable "instances_primary" {
  description = "List of instance configurations for primary region"
  type = list(object({
    type  = string
    count = number
    size  = string
  }))
}

variable "instances_dr" {
  description = "List of instance configurations for DR region"
  type = list(object({
    type  = string
    count = number
    size  = string
  }))
}

variable "test_data" {
  description = "Configuration for test data generation"
  type        = map(any)
  default     = {}
}

# Define resources needed for testing
resource "aws_s3_bucket" "test_data" {
  bucket = "${var.project_name}-dr-test-data"
  acl    = "private"
}

resource "aws_dynamodb_table" "test_metrics" {
  name         = "${var.project_name}-dr-test-metrics"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "test_id"
  range_key    = "timestamp"

  attribute {
    name = "test_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "N"
  }

  point_in_time_recovery {
    enabled = true
  }
}

output "resources" {
  description = "Test resources created for DR testing"
  value = {
    test_data_bucket = aws_s3_bucket.test_data.bucket
    metrics_table    = aws_dynamodb_table.test_metrics.name
  }
}