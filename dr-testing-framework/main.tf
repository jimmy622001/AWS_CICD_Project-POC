variable "project_name" {
  description = "Name of the project being tested"
  type        = string
}

variable "primary_region" {
  description = "Primary AWS region"
  type        = string
}

variable "dr_region" {
  description = "Disaster Recovery AWS region"
  type        = string
}

variable "failover_components" {
  description = "Components to be included in failover testing"
  type        = list(string)
}

variable "test_data" {
  description = "Configuration for test data generation"
  type        = map(any)
  default     = {}
}

variable "validation_checks" {
  description = "List of validation checks to perform"
  type        = list(string)
  default     = ["data_integrity", "service_availability", "response_time"]
}

module "dr_test_pipeline" {
  source = "./modules/dr_test_pipeline"

  project_name        = var.project_name
  primary_region      = var.primary_region
  dr_region           = var.dr_region
  failover_components = var.failover_components
}

module "test_resources" {
  source = "./modules/test_resources"

  project_name  = var.project_name
  primary_region = var.primary_region
  dr_region     = var.dr_region
  test_data     = var.test_data
}

module "validation" {
  source = "./modules/validation"

  project_name      = var.project_name
  validation_checks = var.validation_checks
  primary_region    = var.primary_region
  dr_region         = var.dr_region
}

output "dr_test_environment" {
  description = "DR Test Environment details"
  value = {
    project_name     = var.project_name
    primary_region   = var.primary_region
    dr_region        = var.dr_region
    test_pipeline_id = module.dr_test_pipeline.pipeline_id
    test_resources   = module.test_resources.resources
    validation_urls  = module.validation.validation_endpoints
  }
}