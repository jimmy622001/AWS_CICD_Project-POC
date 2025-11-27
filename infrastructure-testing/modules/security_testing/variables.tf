variable "project_name" {
  description = "Name of the project"
  type        = string
}

variable "environment" {
  description = "Environment (e.g. dev, test, prod)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
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

variable "security_report_bucket" {
  description = "S3 bucket for security reports"
  type        = string
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
}