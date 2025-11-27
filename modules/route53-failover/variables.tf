variable "domain_name" {
  description = "The domain name for the application"
  type        = string
}

variable "primary_endpoint" {
  description = "The DNS name of the primary region endpoint (e.g., load balancer or CloudFront distribution)"
  type        = string
}

variable "dr_endpoint" {
  description = "The DNS name of the DR region endpoint (e.g., load balancer or CloudFront distribution)"
  type        = string
}

variable "primary_zone_id" {
  description = "The hosted zone ID of the primary region endpoint"
  type        = string
}

variable "dr_zone_id" {
  description = "The hosted zone ID of the DR region endpoint"
  type        = string
}

variable "health_check_path" {
  description = "The path for the health check"
  type        = string
  default     = "/health"
}

variable "environment" {
  description = "Environment name (prod, dev, etc.)"
  type        = string
}