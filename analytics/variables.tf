# ============================================================================
# Global Variables
# ============================================================================

variable "aws_region" {
  description = "AWS region to deploy resources in"
  type        = string
  default     = "eu-west-1"
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}

# ============================================================================
# QuickSight Subscription Variable
# ============================================================================

variable "quicksight_subscription" {
  description = "QuickSight subscription configuration. Set to null to skip subscription creation."
  type = object({
    account_name                   = string
    authentication_method          = string
    edition                        = string
    notification_email             = string
    termination_protection_enabled = bool

  })
  default = null
}


# ============================================================================
# Data Source Variables - Athena
# ============================================================================

variable "athena_datasource_name" {
  description = "Athena data source name"
  type        = string
}

variable "athena_workgroup_name" {
  description = "valAthena workgroup for quicksight integrationue"
  type        = string
}


# ============================================================================
# Dataset Variables - Athena
# ============================================================================

variable "glue_database_name" {
  description = "Name of the AWS Glue database (schema)"
  type        = string
}

variable "glue_table_name" {
  description = "Name of the AWS Glue table"
  type        = string
}

variable "athena_dataset" {
  description = "Map of Athena datasets to create"
  type = object({
    name        = string
    import_mode = string
    columns = list(object({
      name = string
      type = string
    }))
  })
}