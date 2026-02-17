variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "datalake_bucket_name" {
  description = "S3 data lake bucket name"
  type        = string
}

variable "glue_database_name" {
  description = "Glue database name"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
