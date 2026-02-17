output "etl_role_arn" {
  value       = aws_iam_role.etl.arn
  description = "ETL role ARN for Glue jobs"
}

output "etl_role_name" {
  value       = aws_iam_role.etl.name
  description = "ETL role name"
}

output "analyst_role_arn" {
  value       = aws_iam_role.analyst.arn
  description = "Analyst role ARN for Athena queries"
}

output "analyst_role_name" {
  value       = aws_iam_role.analyst.name
  description = "Analyst role name"
}

output "ml_role_arn" {
  value       = aws_iam_role.ml.arn
  description = "ML role ARN for SageMaker/Glue"
}

output "ml_role_name" {
  value       = aws_iam_role.ml.name
  description = "ML role name"
}
