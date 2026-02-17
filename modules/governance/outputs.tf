output "lakeformation_service_role_arn" {
  value       = aws_iam_role.lakeformation_service_role.arn
  description = "Lake Formation custom service role ARN"
}

output "lakeformation_service_role_name" {
  value       = aws_iam_role.lakeformation_service_role.name
  description = "Lake Formation custom service role name"
}
