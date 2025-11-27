output "cluster_endpoint" {
  description = "The endpoint URL for the EKS cluster in DR region"
  value       = module.eks.cluster_endpoint
}

output "cluster_zone_id" {
  description = "The Route53 zone ID for the EKS cluster in DR region"
  value       = module.eks.cluster_zone_id
}

output "vpc_id" {
  description = "The VPC ID in the DR region"
  value       = module.vpc.vpc_id
}