resource "aws_route53_health_check" "primary_region" {
  fqdn              = var.primary_endpoint
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "primary-region-health-check"
    Environment = var.environment
  }
}

resource "aws_route53_zone" "main" {
  name = var.domain_name
  
  tags = {
    Environment = var.environment
  }
}

resource "aws_route53_record" "primary" {
  zone_id         = aws_route53_zone.main.zone_id
  name            = var.domain_name
  type            = "A"
  set_identifier  = "primary"
  health_check_id = aws_route53_health_check.primary_region.id

  failover_routing_policy {
    type = "PRIMARY"
  }

  alias {
    name                   = var.primary_endpoint
    zone_id                = var.primary_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "dr" {
  zone_id        = aws_route53_zone.main.zone_id
  name           = var.domain_name
  type           = "A"
  set_identifier = "dr"

  failover_routing_policy {
    type = "SECONDARY"
  }

  alias {
    name                   = var.dr_endpoint
    zone_id                = var.dr_zone_id
    evaluate_target_health = true
  }
}