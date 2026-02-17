variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
}

variable "glue_job_names" {
  description = "Map of Glue job names for orchestration"
  type = object({
    public_api_raw_to_staged      = string
    public_api_data_quality       = string
    public_api_staged_to_curated  = string
    rds_raw_to_staged             = string
    rds_data_quality              = string
    rds_staged_to_curated         = string
  })
}

variable "datalake_bucket_name" {
  description = "Name of the data lake S3 bucket"
  type        = string
}

variable "glue_database_name" {
  description = "Glue database name"
  type        = string
}

variable "enable_schedule" {
  description = "Enable EventBridge schedule for daily orchestration"
  type        = bool
  default     = true
}

variable "schedule_time" {
  description = "Cron expression for daily schedule (default: 2 AM UTC)"
  type        = string
  default     = "cron(0 1 * * ? *)"  # Changed to 1 AM to allow time for ingest
}

variable "lambda_function_arn" {
  description = "ARN of Lambda function for public API ingestion"
  type        = string
}

variable "dms_replication_config_arn" {
  description = "ARN of DMS replication configuration for RDS data (serverless)"
  type        = string
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
}

