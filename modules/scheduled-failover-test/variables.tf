variable "environment" {
  description = "Environment name (e.g., prod, dev)"
  type        = string
}

variable "primary_region" {
  description = "AWS region for the primary environment"
  type        = string
  default     = "us-east-1"
}

variable "dr_region" {
  description = "AWS region for the DR environment"
  type        = string
  default     = "us-west-2"
}

variable "domain_name" {
  description = "Domain name for the application"
  type        = string
}

variable "health_check_path" {
  description = "Path to use for health checking"
  type        = string
  default     = "/health"
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID"
  type        = string
}

variable "primary_endpoint" {
  description = "Endpoint for the primary region"
  type        = string
}

variable "dr_endpoint" {
  description = "Endpoint for the DR region"
  type        = string
}

variable "notification_emails" {
  description = "List of email addresses to notify when failover tests complete or fail"
  type        = list(string)
  default     = []
}