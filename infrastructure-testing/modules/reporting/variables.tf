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

variable "reports_bucket" {
  description = "S3 bucket for storing reports"
  type        = string
}

variable "notification_email" {
  description = "Email address for notifications"
  type        = string
}