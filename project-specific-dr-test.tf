module "project_dr_test" {
  source = "./dr-testing-framework"

  project_name    = "aws-cicd-project"
  primary_region  = "eu-west-1"
  dr_region       = "eu-west-2"

  failover_components = [
    "database",
    "api-services",
    "frontend",
    "eks-cluster"
  ]

  test_data = {
    generate_sample_load = true
    transaction_volume   = "medium"
    include_stress_test  = true
  }

  validation_checks = [
    "data_integrity",
    "service_availability",
    "transaction_consistency",
    "response_time",
    "cluster_health"
  ]
}

output "dr_test_details" {
  value = module.project_dr_test.dr_test_environment
}