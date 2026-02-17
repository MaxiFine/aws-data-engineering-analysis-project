# ============================================================================
# Global Variables
# ============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}


# ============================================================================
# Variables for DMS Infrastructure
# ============================================================================

variable "vpc_id" {
  type        = string
  description = "VPC ID"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet ids for the DMS group"
}

# for vpc gateway endpoint
variable "private_route_table_ids" {
  type        = list(string)
  description = "Private route table ids"
}

variable "replication_instance_sgs" {
  type        = list(string)
  description = "Specifies the virtual private cloud (VPC) security group to use with the DMS Serverless replication."
}

variable "target_s3_bucket_name" {
  type        = string
  description = "Target S3 bucket for DMS output"
}

variable "data_sources_config" {
  type = list(object({
    name          = string # a friendly name like "mysql", "postgres"
    engine_name   = string # DMS engine (mysql, postgres, etc.)
    database_name = string
    secrets_manager_arn : string # ARN of the Secrets Manager secret for the database connection details (must include username, password, host, port)
    s3_prefix = string           # prefix in S3 bucket (e.g. "mysql", "postgres")
    ssl_mode  = optional(string, "none")
  }))

  validation {
    condition = alltrue([
      for ds in var.data_sources_config :
      contains([
        "aurora",
        "aurora-postgresql",
        "mariadb",
        "mongodb",
        "mysql",
        "oracle",
        "postgres",
        "redshift",
        "sqlserver"
      ], lower(ds.engine_name))
    ])
    error_message = "Each engine_name must be one of: aurora, aurora-postgresql, mariadb, mongodb, mysql, oracle, postgres, redshift, or sqlserver."
  }

  validation {
    condition = alltrue([
      for ds in var.data_sources_config : contains(["require", "none", "verify-full", "verify-ca"], lower(ds.ssl_mode))
    ])
    error_message = "Each ssl_mode must be one of: require, none, or verify-full."
  }

  description = "List of configuration for database sources to migrate using DMS (credentials retrieved from Secrets Manager)"
}

variable "data_format" {
  type        = string
  description = "Data output format for the DMS S3 target endpoint. Supported values are 'csv' or 'parquet'."

  validation {
    condition     = contains(["csv", "parquet"], var.data_format)
    error_message = "data_format must be either 'csv' or 'parquet'."
  }

  default = "parquet"
}

variable "compression_type" {
  type        = string
  description = "Specifies how DMS compresses files when writing to the S3 target. Valid values: GZIP or NONE."

  validation {
    condition     = contains(["GZIP", "NONE"], var.compression_type)
    error_message = "compression_type must be either 'GZIP' or 'NONE'."
  }

  default = "NONE"
}


variable "migration_type" {
  type        = string
  description = "Type of DMS migration task. One of 'full-load', 'cdc', or 'full-load-and-cdc'."

  validation {
    condition     = contains(["full-load", "cdc", "full-load-and-cdc"], var.migration_type)
    error_message = "migration_type must be one of 'full-load', 'cdc', or 'full-load-and-cdc'."
  }

  default = "full-load-and-cdc"
}

variable "kms_key_id" {
  description = "The ARN of the KMS key used to encrypt data during DMS Serverless replication. If not provided, the default AWS managed key will be used."
  type        = string
}

variable "existing_dms_vpc_role_arn" {
  description = "ARN of existing dms-vpc-role if it already exists. If provided, the existing role will be reused instead of creating a new one."
  type        = string
  default     = null
  # Example: "arn:aws:iam::517798689069:role/dms-vpc-role"
}
