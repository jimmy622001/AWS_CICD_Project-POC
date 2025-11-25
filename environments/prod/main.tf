provider "aws" {
  region = "us-east-1"
}

module "cicd" {
  source = "../../"
  
  aws_region  = "us-east-1"
  environment = "prod"
  
  # Override any default variables as needed
  repositories = {
    infrastructure = {
      description    = "Infrastructure as Code repository for Production"
      default_branch = "main"
    },
    eks = {
      description    = "EKS configuration repository for Production"
      default_branch = "main"
    },
    application = {
      description    = "Application code repository for Production"
      default_branch = "main"
    }
  }
  
  # Add more environment-specific configurations here
}