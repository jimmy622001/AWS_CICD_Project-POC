provider "aws" {
  region = "us-west-2"  # Different region for disaster recovery
}

module "cicd" {
  source = "../../"
  
  aws_region  = "us-west-2"  # Different region for disaster recovery
  environment = "dr"
  
  # Override any default variables as needed
  repositories = {
    infrastructure = {
      description    = "Infrastructure as Code repository for DR"
      default_branch = "main"
    },
    eks = {
      description    = "EKS configuration repository for DR"
      default_branch = "main"
    },
    application = {
      description    = "Application code repository for DR"
      default_branch = "main"
    }
  }
  
  # Add more environment-specific configurations here
}