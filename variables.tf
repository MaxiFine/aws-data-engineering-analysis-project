variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-west-1"
}

variable "project_name" {
  description = "Project name (used in resource naming)"
  type        = string
  default     = "lakehouse"
}

variable "environment" {
  description = "Environment (dev, staging, prod)"
  type        = string
  default     = "dev"
}

variable "tags" {
  description = "Common tags for all resources"
  type        = map(string)
  default = {
    Project     = "DataBILakehouse"
    ManagedBy   = "Terraform"
    Environment = "Dev"
    Owner       = "Engineering"
  }
}

# Lake Formation configuration
variable "lf_additional_admin_arns" {
  description = "Additional Lake Formation admin ARNs"
  type        = list(string)
  default     = []
}

variable "principal_org_id" {
  description = "AWS Organization ID for cross-account access"
  type        = string
  default     = null
}

# Data Sources configuration
variable "vpc_id" {
  description = "VPC ID for DMS replication instance"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for DMS replication"
  type        = list(string)
}

variable "private_route_table_ids" {
  description = "Private route table IDs for VPC endpoints"
  type        = list(string)
}

variable "replication_instance_sgs" {
  description = "Security group IDs for DMS replication instance"
  type        = list(string)
}

variable "data_sources_config" {
  description = "Configuration for data sources (RDS, etc.)"
  type = list(object({
    name                 = string
    engine_name          = string
    database_name        = string
    ssl_mode             = string
    secrets_manager_arn  = string
    s3_prefix            = string
  }))
}

variable "data_format" {
  description = "Data format for DMS target (csv, parquet)"
  type        = string
  default     = "csv"
}

variable "compression_type" {
  description = "Compression type for DMS target (gzip, none)"
  type        = string
  default     = "none"
}

variable "migration_type" {
  description = "DMS migration type (cdc, full-load, full-load-and-cdc)"
  type        = string
  default     = "full-load-and-cdc"
}

variable "existing_dms_vpc_role_arn" {
  description = "ARN of existing dms-vpc-role if it already exists. If null, creates new."
  type        = string
  default     = null
}

variable "kms_key_id" {
  description = "The ARN of the KMS key used to encrypt data during DMS Serverless replication. If not provided, the default AWS managed key will be used."
  type        = string
}

variable "lambda_function_name" {
  type        = string
  description = "Name of the lambda function to be created"
}


#NOTE: The Analysis module must be deployed separately after the Lakehouse is set up and data is available in Athena.
# The etl orchestration does not run immediately to make the tables (schemas) available for analysis.

# variable "quicksight_subscription" {
#   description = "QuickSight subscription configuration. Set to null to skip subscription creation."
#   type = object({
#     account_name                   = string
#     authentication_method          = string
#     edition                        = string
#     notification_email             = string
#     termination_protection_enabled = bool

#   })
#   default = null
# }

# variable "athena_datasource_name" {
#   description = "Name of the Athena data source"
#   type = string
# }

# variable "glue_table_name" {
#   description = "Name of the AWS Glue table"
#   type = string
# }

# variable "athena_dataset" {
#   description = "Map of Athena datasets to create"
#   type = object({
#     name        = string
#     import_mode = string
#     columns = list(object({
#       name = string
#       type = string
#     }))
#   })
# }