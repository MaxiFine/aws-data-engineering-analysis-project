data "aws_caller_identity" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  lf_service_role_arn = "arn:aws:iam::${local.account_id}:role/CustomServiceRoleForLakeFormationDataAccess_${var.resource_prefix}"
}

# Primary S3 data lake bucket
resource "aws_s3_bucket" "datalake" {
  bucket = "${var.resource_prefix}-datalake"
  tags   = var.tags
}

# Enable versioning
resource "aws_s3_bucket_versioning" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Server-side encryption with KMS
resource "aws_s3_bucket_server_side_encryption_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = var.kms_key_arn
    }
    bucket_key_enabled = true
  }
}

# Block all public access
resource "aws_s3_bucket_public_access_block" "datalake" {
  bucket                  = aws_s3_bucket.datalake.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 bucket policy: TLS-only + Lake Formation service role access
locals {
  s3_policy = {
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource = [
            aws_s3_bucket.datalake.arn,
            "${aws_s3_bucket.datalake.arn}/*"
          ]
          Condition = {
            Bool = { "aws:SecureTransport" = false }
          }
        },
        {
          Sid       = "AllowLakeFormationServiceRole"
          Effect    = "Allow"
          Principal = { AWS = local.lf_service_role_arn }
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            aws_s3_bucket.datalake.arn,
            "${aws_s3_bucket.datalake.arn}/*"
          ]
        }
      ],
      var.principal_org_id != null ? [
        {
          Sid       = "AllowOrgPrincipals"
          Effect    = "Allow"
          Principal = "*"
          Action = [
            "s3:GetObject",
            "s3:PutObject",
            "s3:DeleteObject",
            "s3:ListBucket",
            "s3:GetBucketLocation"
          ]
          Resource = [
            aws_s3_bucket.datalake.arn,
            "${aws_s3_bucket.datalake.arn}/*"
          ]
          Condition = {
            StringEquals = { "aws:PrincipalOrgID" = var.principal_org_id }
          }
        }
      ] : []
    )
  }
}

resource "aws_s3_bucket_policy" "datalake" {
  bucket = aws_s3_bucket.datalake.id
  policy = jsonencode(local.s3_policy)
}

# Lifecycle policies: transition to Glacier after 180 days per tier
resource "aws_s3_bucket_lifecycle_configuration" "datalake" {
  bucket = aws_s3_bucket.datalake.id

  rule {
    id     = "raw-tier-to-glacier"
    status = "Enabled"
    filter {
      prefix = "raw/"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "staged-tier-to-glacier"
    status = "Enabled"
    filter {
      prefix = "staged/"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }

  rule {
    id     = "curated-tier-to-glacier"
    status = "Enabled"
    filter {
      prefix = "curated/"
    }
    transition {
      days          = 180
      storage_class = "GLACIER"
    }
  }
}
