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
  name           = "${var.project_name}-dr-test-metrics"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "test_id"
  range_key      = "timestamp"

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