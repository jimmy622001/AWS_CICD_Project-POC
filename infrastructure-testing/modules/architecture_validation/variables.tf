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

variable "trusted_advisor_schedule" {
  description = "Schedule expression for running Trusted Advisor checks"
  type        = string
  default     = "rate(7 days)"
}

variable "report_bucket" {
  description = "S3 bucket for storing reports"
  type        = string
}