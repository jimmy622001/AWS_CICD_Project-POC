variable "project_name" {
  description = "Name of the project being tested"
  type        = string
  default     = "aws-cicd-project"
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
  default     = "us-west-2"
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
  default     = "us-east-1"
}

variable "failover_components" {
  description = "Components to be included in failover testing"
  type        = list(string)
  default     = ["ec2", "rds", "s3", "lambda", "dynamodb"]
}

variable "test_data" {
  description = "Configuration for test data generation"
  type        = map(any)
  default     = {
    size_mb = 100
    type    = "random"
    format  = "json"
  }
}

variable "validation_checks" {
  description = "List of validation checks to perform"
  type        = list(string)
  default     = ["data_integrity", "service_availability", "response_time"]
}

variable "vpc_cidr_primary" {
  description = "CIDR block for the primary VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "vpc_cidr_dr" {
  description = "CIDR block for the DR VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "subnets_primary" {
  description = "Subnets for the primary environment"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "subnets_dr" {
  description = "Subnets for the DR environment"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24"]
}

variable "instances_primary" {
  description = "Instance configuration for primary environment"
  type        = list(object({
    type  = string
    count = number
    size  = string
  }))
  default = [
    {
      type  = "web"
      count = 2
      size  = "t3.medium"
    },
    {
      type  = "db"
      count = 1
      size  = "m5.large"
    }
  ]
}

variable "instances_dr" {
  description = "Instance configuration for DR environment"
  type        = list(object({
    type  = string
    count = number
    size  = string
  }))
  default = [
    {
      type  = "web"
      count = 2
      size  = "t3.medium"
    },
    {
      type  = "db"
      count = 1
      size  = "m5.large"
    }
  ]
}

variable "test_timeout_minutes" {
  description = "Test timeout in minutes"
  type        = number
  default     = 30
}

variable "rto_threshold_minutes" {
  description = "Recovery Time Objective threshold in minutes"
  type        = number
  default     = 15
}

variable "rpo_threshold_minutes" {
  description = "Recovery Point Objective threshold in minutes"
  type        = number
  default     = 60
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
  default     = "team@example.com"
}

variable "fis_experiments" {
  description = "AWS Fault Injection Simulator experiments to run"
  type        = list(string)
  default     = ["cpu-stress", "network-latency"]
}