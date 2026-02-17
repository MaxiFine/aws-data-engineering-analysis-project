# ============================================================================
# Global Variables
# ============================================================================

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
}


# ============================================================================
# Lambda Variable
# ============================================================================

variable "lambda_function_name" {
  type        = string
  description = "The name of the lambda function"
}


# ============================================================================
# Lakehouse Variable - S3 Bucket
# ============================================================================

variable "s3_bucket_name" {
  type        = string
  description = "Target S3 bucket name for CSV uploads"
}
