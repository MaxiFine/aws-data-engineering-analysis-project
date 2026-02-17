output "public_api_raw_to_staged_job_name" {
  description = "Public API Raw to Staged Glue job name"
  value       = aws_glue_job.public_api_raw_to_staged.name
}

output "public_api_staged_to_curated_job_name" {
  description = "Public API Staged to Curated Glue job name"
  value       = aws_glue_job.public_api_staged_to_curated.name
}

output "public_api_data_quality_job_name" {
  description = "Public API Data Quality Glue job name"
  value       = aws_glue_job.public_api_data_quality.name
}

output "rds_raw_to_staged_job_name" {
  description = "RDS Raw to Staged Glue job name"
  value       = aws_glue_job.rds_raw_to_staged.name
}

output "rds_data_quality_job_name" {
  description = "RDS Data Quality Glue job name"
  value       = aws_glue_job.rds_data_quality.name
}

output "rds_staged_to_curated_job_name" {
  description = "RDS Staged to Curated Glue job name"
  value       = aws_glue_job.rds_staged_to_curated.name
}

output "glue_job_role_arn" {
  description = "Glue job IAM role ARN"
  value       = aws_iam_role.glue_job_role.arn
}
