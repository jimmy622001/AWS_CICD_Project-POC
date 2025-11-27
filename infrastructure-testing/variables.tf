variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (e.g. dev, test, prod)"
  type        = string
  default     = "dev"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "account_id" {
  description = "AWS account ID"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for testing"
  type        = string
}

variable "inspector_schedule" {
  description = "Schedule expression for running Inspector assessments"
  type        = string
  default     = "rate(7 days)"
}

variable "enable_security_hub" {
  description = "Whether to enable Security Hub"
  type        = bool
  default     = true
}

variable "enable_guardduty" {
  description = "Whether to enable GuardDuty"
  type        = bool
  default     = true
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
}

variable "api_endpoints" {
  description = "List of API endpoints to test"
  type        = list(object({
    name = string
    url  = string
    method = string
    expected_status_code = number
  }))
  default     = []
}

variable "canary_schedule" {
  description = "Schedule expression for running Synthetic canaries"
  type        = string
  default     = "rate(5 minutes)"
}

variable "trusted_advisor_schedule" {
  description = "Schedule expression for running Trusted Advisor checks"
  type        = string
  default     = "rate(7 days)"
}

variable "xray_sampling_rate" {
  description = "X-Ray sampling rate (0.0-1.0)"
  type        = number
  default     = 0.05
}

variable "testing_schedule" {
  description = "Schedule expression for running all tests"
  type        = string
  default     = "cron(0 0 ? * SUN *)" # Weekly on Sunday at midnight
}