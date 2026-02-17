variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "datalake_bucket_arn" {
  description = "ARN of the S3 data lake bucket"
  type        = string
}

variable "glue_database_name" {
  description = "Glue catalog database name"
  type        = string
}

variable "lf_service_role_arn" {
  description = "Lake Formation custom service role ARN"
  type        = string
}

variable "admin_principals" {
  description = "List of principal ARNs with full Lake Formation admin control"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
