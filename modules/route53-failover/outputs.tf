output "zone_id" {
  description = "The ID of the Route53 hosted zone"
  value       = aws_route53_zone.main.zone_id
}

output "hosted_zone_id" {
  description = "The ID of the Route53 hosted zone (alias for zone_id)"
  value       = aws_route53_zone.main.zone_id
}

output "name_servers" {
  description = "Name servers for the Route53 hosted zone"
  value       = aws_route53_zone.main.name_servers
}

output "health_check_id" {
  description = "ID of the primary region health check"
  value       = aws_route53_health_check.primary_region.id
}