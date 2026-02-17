output "kms_key_id" {
  value       = aws_kms_key.lakehouse.id
  description = "KMS key ID"
}

output "kms_key_arn" {
  value       = aws_kms_key.lakehouse.arn
  description = "KMS key ARN"
}

output "kms_alias" {
  value       = aws_kms_alias.lakehouse.name
  description = "KMS key alias"
}
