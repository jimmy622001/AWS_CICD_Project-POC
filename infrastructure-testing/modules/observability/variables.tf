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

variable "xray_sampling_rate" {
  description = "X-Ray sampling rate (0.0-1.0)"
  type        = number
  default     = 0.05
}