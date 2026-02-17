variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for Athena results encryption"
  type        = string
}

variable "glue_database" {
  description = "Glue database name for Athena views"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
