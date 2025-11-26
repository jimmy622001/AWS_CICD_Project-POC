# Main configuration file for DR testing framework
# Variables are defined in variables.tf

module "dr_test_pipeline" {
  source = "./modules/dr_test_pipeline"

  project_name        = var.project_name
  primary_region      = var.primary_region
  dr_region           = var.dr_region
  failover_components = var.failover_components

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }
}

module "test_resources" {
  source = "./modules/test_resources"

  project_name   = var.project_name
  primary_region = var.primary_region
  dr_region      = var.dr_region
  test_data      = var.test_data

  vpc_cidr_primary = var.vpc_cidr_primary
  vpc_cidr_dr     = var.vpc_cidr_dr
  subnets_primary = var.subnets_primary
  subnets_dr      = var.subnets_dr
  instances_primary = var.instances_primary
  instances_dr     = var.instances_dr

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }
}

module "validation" {
  source = "./modules/validation"

  project_name      = var.project_name
  validation_checks = var.validation_checks
  primary_region    = var.primary_region
  dr_region         = var.dr_region
  test_timeout_minutes = var.test_timeout_minutes
  rto_threshold_minutes = var.rto_threshold_minutes
  rpo_threshold_minutes = var.rpo_threshold_minutes
  notification_email = var.notification_email
  fis_experiments    = var.fis_experiments

  providers = {
    aws.primary = aws.primary
    aws.dr      = aws.dr
  }
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