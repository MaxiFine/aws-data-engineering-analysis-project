output "athena_workgroup_name" {
  value       = aws_athena_workgroup.lakehouse.name
  description = "Athena workgroup name for v3 Iceberg queries"
}

output "athena_results_bucket" {
  value       = aws_s3_bucket.athena_results.id
  description = "S3 bucket for Athena query results"
}

output "athena_results_bucket_arn" {
  value       = aws_s3_bucket.athena_results.arn
  description = "ARN of Athena results bucket"
}
