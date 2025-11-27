variable "environment" {
  description = "Environment name (e.g. dr)"
  type        = string
  default     = "dr"
}

variable "primary_region" {
  description = "AWS region of the primary environment"
  type        = string
}

variable "dr_region" {
  description = "AWS region for disaster recovery"
  type        = string
  default     = "us-west-2"
}