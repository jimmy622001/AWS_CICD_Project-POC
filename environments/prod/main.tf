provider "aws" {
  region = var.region
}

terraform {
  required_version = ">= 1.0.0"

  # Using local state file for now
  # Consider using S3 backend for production

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.10"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.5"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project             = var.project
  environment         = var.environment
  region              = var.region
  vpc_cidr            = var.vpc_cidr
  public_subnet_cidr  = var.public_subnet_cidr
  private_subnet_cidr = var.private_subnet_cidr
  db_subnet_cidr      = var.db_subnet_cidr
  availability_zone   = var.availability_zone
  tags                = var.tags
}

# EKS Module
module "eks" {
  source = "../../modules/eks"

  project             = var.project
  environment         = var.environment
  region              = var.region
  cluster_name        = "${var.project}-${var.environment}-cluster"
  vpc_id              = module.vpc.vpc_id
  subnet_ids          = [module.vpc.private_subnet_id, module.vpc.public_subnet_id]
  cluster_version     = var.cluster_version
  node_instance_types = var.node_instance_types
  node_desired_size   = var.node_desired_size
  node_max_size       = var.node_max_size
  node_min_size       = var.node_min_size
  tags                = var.tags
}

# Data source to get EKS cluster info
data "aws_eks_cluster" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Data source for auth info
data "aws_eks_cluster_auth" "eks" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

# Configure Kubernetes provider to access EKS cluster
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks.token
}

# Configure Helm provider
provider "helm" {
  kubernetes = {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.eks.token
  }
}

# Configure DR region provider
provider "aws" {
  alias  = "dr"
  region = var.dr_region
}

# DR Module for Disaster Recovery
module "dr" {
  source = "../../environments/dr"

  # Pass necessary variables to DR module
  environment = "dr"
  primary_region = var.region
  dr_region = var.dr_region

  providers = {
    aws = aws.dr
  }
}

# Route53 Failover Configuration
module "route53_failover" {
  source = "../../modules/route53-failover"

  environment     = var.environment
  domain_name     = var.domain_name
  primary_endpoint = module.eks.cluster_endpoint
  primary_zone_id = module.eks.cluster_zone_id
  dr_endpoint     = module.dr.cluster_endpoint
  dr_zone_id      = module.dr.cluster_zone_id
  health_check_path = "/health"
}

# Scheduled Failover Testing
module "scheduled_failover_test" {
  source = "../../modules/scheduled-failover-test"

  environment        = var.environment
  primary_region     = var.region
  dr_region          = var.dr_region
  domain_name        = var.domain_name
  hosted_zone_id     = module.route53_failover.hosted_zone_id
  primary_endpoint   = module.eks.cluster_endpoint
  dr_endpoint        = module.dr.cluster_endpoint
  health_check_path  = "/health"
  notification_emails = var.notification_emails
}