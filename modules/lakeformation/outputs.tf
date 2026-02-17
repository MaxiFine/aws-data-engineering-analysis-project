output "sensitivity_tag_key" {
  value       = aws_lakeformation_lf_tag.sensitivity.key
  description = "Lake Formation sensitivity tag key"
}

output "domain_tag_key" {
  value       = aws_lakeformation_lf_tag.domain.key
  description = "Lake Formation domain tag key"
}

output "sensitivity_tag_values" {
  value       = aws_lakeformation_lf_tag.sensitivity.values
  description = "Lake Formation sensitivity tag values"
}

output "domain_tag_values" {
  value       = aws_lakeformation_lf_tag.domain.values
  description = "Lake Formation domain tag values"
}
