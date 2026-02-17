variable "resource_prefix" {
  description = "Prefix for resource naming"
  type        = string
}

variable "datalake_bucket_name" {
  description = "S3 data lake bucket name (for Glue database location)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}
