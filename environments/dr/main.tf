terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
  }
}

# Provider configuration is passed from the root module

# VPC Module for DR environment
module "vpc" {
  source = "../../modules/vpc"

  project             = "${var.environment}-${var.primary_region}"
  environment         = var.environment
  region              = var.dr_region
  vpc_cidr            = "10.1.0.0/16" # Different CIDR for DR environment
  public_subnet_cidr  = "10.1.1.0/24"
  private_subnet_cidr = "10.1.2.0/24"
  db_subnet_cidr      = "10.1.3.0/24"
  availability_zone   = "a"
  tags                = {
    Environment = var.environment
    Project     = "DR-${var.primary_region}"
  }
}

# EKS Module for DR environment
module "eks" {
  source = "../../modules/eks"

  project             = "dr-${var.primary_region}"
  environment         = var.environment
  region              = var.dr_region
  cluster_name        = "dr-${var.primary_region}-cluster"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = [module.vpc.private_subnet_id, module.vpc.public_subnet_id]
  cluster_version     = "1.27"
  node_instance_types = ["t3.medium"]
  node_desired_size   = 1
  node_max_size       = 2
  node_min_size       = 1
  tags                = {
    Environment = var.environment
    Project     = "DR-${var.primary_region}"
  }
}

# CICD for DR environment (optional)
module "cicd" {
  source = "../../"

  aws_region  = var.dr_region
  environment = var.environment
  project     = "dr-${var.primary_region}"

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
}