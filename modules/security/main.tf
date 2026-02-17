data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  account_id          = data.aws_caller_identity.current.account_id
  account_root_arn    = "arn:aws:iam::${local.account_id}:root"
  lf_service_role_arn = "arn:aws:iam::${local.account_id}:role/CustomServiceRoleForLakeFormationDataAccess_${var.resource_prefix}"
}

# Build KMS policy with root + Lake Formation service role
locals {
  base_statements = [
    {
      Sid       = "AllowRootAccount"
      Effect    = "Allow"
      Action    = ["kms:*"]
      Principal = { AWS = local.account_root_arn }
      Resource  = "*"
    },
    {
      Sid       = "AllowLakeFormationServiceRole"
      Effect    = "Allow"
      Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
      Principal = { AWS = local.lf_service_role_arn }
      Resource  = "*"
    },
    {
      Sid       = "AllowDMSAccess"
      Effect    = "Allow"
      Action    = ["kms:Encrypt","kms:Decrypt","kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:CreateGrant", "kms:DescribeKey", "kms:ListGrants"]
      Principal = "*"
      Resource  = "*"
      Condition = {
        StringEquals = {
          "kms:CallerAccount" = local.account_id,
          "kms:ViaService"    = "dms.${data.aws_region.current.name}.amazonaws.com"
        }
      }
    },
    {
      Sid       = "AllowGlueToUseKey"
      Effect    = "Allow"
      Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
      Principal = { Service = "glue.amazonaws.com" }
      Resource  = "*"
    }
  
  ]



  org_statements = var.principal_org_id != null ? [
    {
      Sid       = "AllowOrgPrincipals"
      Effect    = "Allow"
      Action    = ["kms:Encrypt", "kms:Decrypt", "kms:ReEncrypt*", "kms:GenerateDataKey*", "kms:DescribeKey"]
      Principal = "*"
      Resource  = "*"
      Condition = {
        StringEquals = { "aws:PrincipalOrgID" = var.principal_org_id }
      }
    }
  ] : []

  kms_policy = {
    Version   = "2012-10-17"
    Statement = concat(local.base_statements, local.org_statements)
  }
}

# Customer-managed CMK for S3 and Athena encryption
resource "aws_kms_key" "lakehouse" {
  description             = "KMS key for Data & BI Lakehouse encryption"
  enable_key_rotation     = true
  deletion_window_in_days = 10
  policy                  = jsonencode(local.kms_policy)
  tags                    = var.tags
}

resource "aws_kms_alias" "lakehouse" {
  name          = "alias/${var.resource_prefix}-kms"
  target_key_id = aws_kms_key.lakehouse.id
}
