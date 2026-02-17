data "aws_caller_identity" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  # Admins: root + any passed admin principals
  admins = concat(["arn:aws:iam::${local.account_id}:root"], var.admin_principals)
}

# NOTE: Lake Formation data lake settings (admins, default permissions) are managed MANUALLY
# to preserve frank-aws-starter-profile as a permanent admin. This prevents accidental
# removal during terraform destroy, which would block resource deletion.
# To setup: AWS Console > Lake Formation > Settings > Add Data Lake Admin
# Terraform only manages LF tags, permissions, and resource registration.

# Reference to data lake settings (data source) for depends_on
data "aws_lakeformation_data_lake_settings" "this" {}

# Register S3 data lake location with Lake Formation
resource "aws_lakeformation_resource" "datalake" {
  arn             = var.datalake_bucket_arn
  role_arn        = var.lf_service_role_arn
  use_service_linked_role = false
}

# Lake Formation Tags per usecasedetail.md (line 70)
# sensitivity: pii, internal, public
resource "aws_lakeformation_lf_tag" "sensitivity" {
  key    = "sensitivity"
  values = ["pii", "internal", "public"]

  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

# domain: sales, marketing, product, finance
resource "aws_lakeformation_lf_tag" "domain" {
  key    = "domain"
  values = ["sales", "marketing", "product", "finance"]

  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

# Admin Principals: Full control over everything
resource "aws_lakeformation_permissions" "admin_data_location" {
  for_each = toset(var.admin_principals)

  principal   = each.value
  permissions = ["DATA_LOCATION_ACCESS"]
  data_location {
    arn = var.datalake_bucket_arn
  }
  depends_on = [aws_lakeformation_resource.datalake]
}

# Grant explicit DROP permission for Glue database deletion during destroy
resource "aws_lakeformation_permissions" "admin_database_drop" {
  for_each = toset(var.admin_principals)

  principal   = each.value
  permissions = ["DROP"]
  database {
    name = var.glue_database_name
  }
  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

# Grant ALL permissions on database to admin principals
resource "aws_lakeformation_permissions" "admin_database" {
  for_each = toset(var.admin_principals)

  principal   = each.value
  permissions = ["ALL"]
  database {
    name = var.glue_database_name
  }
  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

# Database-level permissions for Glue database
# Grants DESCRIBE on database for discovery
resource "aws_lakeformation_permissions" "database_describe_etl" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-etl-role"
  permissions = ["DESCRIBE"]
  database {
    name = var.glue_database_name
  }
  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "database_describe_analyst" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-analyst-role"
  permissions = ["DESCRIBE"]
  database {
    name = var.glue_database_name
  }
  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

resource "aws_lakeformation_permissions" "database_describe_ml" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-ml-role"
  permissions = ["DESCRIBE"]
  database {
    name = var.glue_database_name
  }
  depends_on = [data.aws_lakeformation_data_lake_settings.this]
}

# Data Location Access for S3 bucket per usecasedetail.md (line 29)
# ETL role: full access to create/manage Iceberg tables
resource "aws_lakeformation_permissions" "data_location_etl" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-etl-role"
  permissions = ["DATA_LOCATION_ACCESS"]
  data_location {
    arn = var.datalake_bucket_arn
  }
  depends_on = [aws_lakeformation_resource.datalake]
}

# Analyst role: read-only access to data location
resource "aws_lakeformation_permissions" "data_location_analyst" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-analyst-role"
  permissions = ["DATA_LOCATION_ACCESS"]
  data_location {
    arn = var.datalake_bucket_arn
  }
  depends_on = [aws_lakeformation_resource.datalake]
}

# ML role: read-only access to data location
resource "aws_lakeformation_permissions" "data_location_ml" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-ml-role"
  permissions = ["DATA_LOCATION_ACCESS"]
  data_location {
    arn = var.datalake_bucket_arn
  }
  depends_on = [aws_lakeformation_resource.datalake]
}

# Tag-based Table Permissions per usecasedetail.md (line 70-72)
# ETL: Can SELECT/INSERT/ALTER on all domains and sensitivity levels
resource "aws_lakeformation_permissions" "etl_table_policy" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-etl-role"
  permissions = ["SELECT", "INSERT", "ALTER"]
  lf_tag_policy {
    resource_type = "TABLE"
    expression {
      key    = aws_lakeformation_lf_tag.domain.key
      values = ["sales", "marketing", "product", "finance"]
    }
  }
  depends_on = [aws_lakeformation_lf_tag.domain]
}

# Analyst: SELECT only on internal/public data (exclude PII)
resource "aws_lakeformation_permissions" "analyst_table_policy" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-analyst-role"
  permissions = ["SELECT"]
  lf_tag_policy {
    resource_type = "TABLE"
    expression {
      key    = aws_lakeformation_lf_tag.sensitivity.key
      values = ["internal", "public"]
    }
  }
  depends_on = [aws_lakeformation_lf_tag.sensitivity]
}

# ML: SELECT on all domains but only non-PII data
resource "aws_lakeformation_permissions" "ml_table_policy" {
  principal   = "arn:aws:iam::${local.account_id}:role/lakehouse-ml-role"
  permissions = ["SELECT"]
  lf_tag_policy {
    resource_type = "TABLE"
    expression {
      key    = aws_lakeformation_lf_tag.domain.key
      values = ["sales", "marketing", "product", "finance"]
    }
    expression {
      key    = aws_lakeformation_lf_tag.sensitivity.key
      values = ["internal", "public"]
    }
  }
  depends_on = [
    aws_lakeformation_lf_tag.domain,
    aws_lakeformation_lf_tag.sensitivity
  ]
}
