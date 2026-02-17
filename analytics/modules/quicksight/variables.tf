# ============================================================================
# Global Variables
# ============================================================================

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

  validation {
    condition     = var.quicksight_subscription == null || contains(["IAM_AND_QUICKSIGHT", "IAM_ONLY", "ACTIVE_DIRECTORY"], var.quicksight_subscription.authentication_method)
    error_message = "Authentication method must be one of: IAM_AND_QUICKSIGHT, IAM_ONLY, ACTIVE_DIRECTORY"
  }
  validation {
    condition     = var.quicksight_subscription == null || contains(["ENTERPRISE", "ENTERPRISE_AND_Q"], var.quicksight_subscription.edition)
    error_message = "Edition must be either ENTERPRISE or ENTERPRISE_AND_Q"
  }
  validation {
    condition     = var.quicksight_subscription == null || can(regex("^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$", var.quicksight_subscription.notification_email))
    error_message = "Notification email must be a valid email address"
  }
  validation {
    condition     = var.quicksight_subscription == null || length(var.quicksight_subscription.account_name) >= 3
    error_message = "Account name must be at least 3 characters long"
  }
}


# ============================================================================
# Data Source Variables - Athena
# ============================================================================

variable "athena_datasource_name" {
  description = "Athena data source name"
  type        = string
}

variable "athena_workgroup_name" {
  description = "Athena workgroup for quicksight integration"
  type        = string
}


# ============================================================================
# Dataset Variables - Athena
# ============================================================================

variable "glue_database_name" {
  description = "Name of the AWS Glue database (schema)"
  type        = string

  validation {
    condition     = length(var.glue_database_name) >= 1
    error_message = "Database name cannot be empty"
  }
}

variable "glue_table_name" {
  description = "Name of the AWS Glue table"
  type        = string

  validation {
    condition     = length(var.glue_table_name) >= 1
    error_message = "Table name cannot be empty"
  }
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

  validation {
    condition     = contains(["SPICE", "DIRECT_QUERY"], var.athena_dataset.import_mode)
    error_message = "Import mode must be either SPICE or DIRECT_QUERY"
  }
}
