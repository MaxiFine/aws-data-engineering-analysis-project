variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key ARN for S3 encryption"
  type        = string
}

variable "principal_org_id" {
  description = "AWS Organization ID for org-wide access (optional)"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
