output "glue_database_name" {
  value       = aws_glue_catalog_database.lakehouse.name
  description = "Glue catalog database name"
}

output "glue_database_arn" {
  value       = aws_glue_catalog_database.lakehouse.arn
  description = "Glue database ARN"
}
