# S3 bucket for Athena query results
# Per usecasedetail.md: cost control includes lifecycle for query results
resource "aws_s3_bucket" "athena_results" {
  bucket = "${var.resource_prefix}-athena-results"
  tags   = var.tags
}

# Enable versioning for audit trail
resource "aws_s3_bucket_versioning" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "athena_results" {
  bucket                  = aws_s3_bucket.athena_results.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Lifecycle policy to clean up query results per usecasedetail.md cost control
resource "aws_s3_bucket_lifecycle_configuration" "athena_results" {
  bucket = aws_s3_bucket.athena_results.id

  rule {
    id     = "delete-old-query-results"
    status = "Enabled"
    filter {
      prefix = "results/"
    }
    expiration {
      days = 7
    }
  }
}

# Athena Workgroup v3 - Supports Apache Iceberg per usecasedetail.md
# Engine v3 provides ACID transactions, schema evolution, time-travel capabilities
resource "aws_athena_workgroup" "lakehouse" {
  name = "${var.resource_prefix}-wg"

  configuration {
    enforce_workgroup_configuration    = true
    publish_cloudwatch_metrics_enabled = true

    engine_version {
      selected_engine_version = "Athena engine version 3"
    }

    result_configuration {
      output_location = "s3://${aws_s3_bucket.athena_results.bucket}/results/"
      encryption_configuration {
        encryption_option = "SSE_KMS"
        kms_key_arn       = var.kms_key_arn
      }
    }

    # Byte scanned limit for cost control per usecasedetail.md
    bytes_scanned_cutoff_per_query = 1073741824  # 1 GB limit
  }

  tags = var.tags
}
