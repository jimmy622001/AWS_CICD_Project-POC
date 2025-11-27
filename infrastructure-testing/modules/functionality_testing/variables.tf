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

variable "code_bucket" {
  description = "S3 bucket for code artifacts"
  type        = string
}

variable "canary_schedule" {
  description = "Schedule expression for running Synthetic canaries"
  type        = string
  default     = "rate(5 minutes)"
}