output "datalake_bucket_name" {
  value       = aws_s3_bucket.datalake.id
  description = "Data lake bucket name"
}

output "datalake_bucket_arn" {
  value       = aws_s3_bucket.datalake.arn
  description = "Data lake bucket ARN"
}
