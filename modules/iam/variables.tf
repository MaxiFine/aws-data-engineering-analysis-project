variable "datalake_bucket_arn" {
  description = "ARN of the S3 data lake bucket"
  type        = string
}

variable "athena_results_bucket_arn" {
  description = "ARN of the Athena results bucket"
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
