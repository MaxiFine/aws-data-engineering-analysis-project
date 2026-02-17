# DynamoDB table for public API data quality audit trail

resource "aws_dynamodb_table" "public_api_quality_audit" {
  name             = "data_quality_audit_public_api"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "job_run_id"
  range_key        = "timestamp"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "job_run_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # Global Secondary Index for querying by execution date
  global_secondary_index {
    name            = "date_index"
    hash_key        = "execution_date"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  attribute {
    name = "execution_date"
    type = "S"
  }

  # TTL for automatic cleanup (90 days)
  ttl {
    attribute_name = "ttl_timestamp"
    enabled        = true
  }

  tags = merge(
    var.tags,
    {
      Name = "data_quality_audit_public_api"
    }
  )

  lifecycle {
    ignore_changes = all
  }
}

# RDS Data Quality Audit Table
resource "aws_dynamodb_table" "rds_quality_audit" {
  name             = "data_quality_audit_rds"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "job_run_id"
  range_key        = "timestamp"
  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  attribute {
    name = "job_run_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  # Global Secondary Index for querying by execution date
  global_secondary_index {
    name            = "date_index"
    hash_key        = "execution_date"
    range_key       = "timestamp"
    projection_type = "ALL"
  }

  attribute {
    name = "execution_date"
    type = "S"
  }

  # TTL for automatic cleanup (90 days)
  ttl {
    attribute_name = "ttl_timestamp"
    enabled        = true
  }

  tags = merge(
    var.tags,
    {
      Name = "data_quality_audit_rds"
    }
  )

  lifecycle {
    ignore_changes = all
  }
}
