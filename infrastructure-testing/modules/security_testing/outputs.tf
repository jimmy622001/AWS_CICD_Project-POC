output "inspector_assessment_template_arn" {
  description = "ARN of the Inspector assessment template"
  value       = aws_inspector_assessment_template.template.arn
}

output "security_hub_enabled" {
  description = "Whether Security Hub is enabled"
  value       = var.enable_security_hub
}

output "guardduty_enabled" {
  description = "Whether GuardDuty is enabled"
  value       = var.enable_guardduty
}

output "guardduty_detector_id" {
  description = "ID of the GuardDuty detector"
  value       = var.enable_guardduty ? aws_guardduty_detector.guardduty[0].id : null
}

output "outputs" {
  description = "All outputs for module integration"
  value = {
    inspector_assessment_template_arn = aws_inspector_assessment_template.template.arn
    inspector_processor_function      = aws_lambda_function.process_inspector_findings.function_name
    security_hub_enabled              = var.enable_security_hub
    guardduty_enabled                 = var.enable_guardduty
    guardduty_detector_id             = var.enable_guardduty ? aws_guardduty_detector.guardduty[0].id : null
  }
}

output "config" {
  description = "Configuration for the security testing module"
  value = {
    inspector_assessment_template_arn = aws_inspector_assessment_template.template.arn
    security_report_bucket           = var.security_report_bucket
    environment                      = var.environment
  }
}