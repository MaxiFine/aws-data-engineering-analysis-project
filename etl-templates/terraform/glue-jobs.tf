locals {
  public_api_raw_to_staged_job      = "public-api-raw-to-staged"
  public_api_staged_to_curated_job  = "public-api-staged-to-curated"
  public_api_data_quality_job       = "public-api-data-quality"
  rds_raw_to_staged_job             = "rds-raw-to-staged"
  rds_staged_to_curated_job         = "rds-staged-to-curated"
  rds_data_quality_job              = "rds-data-quality"
}

# Upload Glue job scripts to S3
resource "aws_s3_object" "public_api_raw_to_staged_script" {
  bucket = var.datalake_bucket_name
  key    = "scripts/glue-jobs/public-api-raw-to-staged/job.py"
  source = "${path.module}/../glue-jobs/public-api-raw-to-staged/job.py"
  etag   = filemd5("${path.module}/../glue-jobs/public-api-raw-to-staged/job.py")

  tags = var.tags
}

resource "aws_s3_object" "public_api_staged_to_curated_script" {
  bucket = var.datalake_bucket_name
  key    = "scripts/glue-jobs/public-api-staged-to-curated/job.py"
  source = "${path.module}/../glue-jobs/public-api-staged-to-curated/job.py"
  etag   = filemd5("${path.module}/../glue-jobs/public-api-staged-to-curated/job.py")

  tags = var.tags
}

resource "aws_s3_object" "public_api_data_quality_script" {
  bucket = var.datalake_bucket_name
  key    = "scripts/glue-jobs/public-api-data-quality/job.py"
  source = "${path.module}/../glue-jobs/public-api-data-quality/job.py"
  etag   = filemd5("${path.module}/../glue-jobs/public-api-data-quality/job.py")

  tags = var.tags
}

# IAM role for Glue job
resource "aws_iam_role" "glue_job_role" {
  name = "${var.resource_prefix}-glue-etl-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "glue.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach basic Glue service policy
resource "aws_iam_role_policy_attachment" "glue_service_policy" {
  role       = aws_iam_role.glue_job_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

# Custom policy for S3, Glue Catalog, KMS, and Lake Formation access
resource "aws_iam_role_policy" "glue_job_policy" {
  name = "${var.resource_prefix}-glue-etl-policy"
  role = aws_iam_role.glue_job_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3DataLakeAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.datalake_bucket_name}",
          "arn:aws:s3:::${var.datalake_bucket_name}/*"
        ]
      },
      {
        Sid    = "GlueCatalogAccess"
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:UpdateTable",
          "glue:CreateTable",
          "glue:DeleteTable",
          "glue:GetPartitions",
          "glue:BatchCreatePartition",
          "glue:GetJob",
          "glue:GetJobRun",
          "glue:PutDataCatalogEncryptionSettings",
          "glue:GetDatabase",
          "glue:BatchGetPartition",
          "glue:GetColumns",
          "glue:GetDatabases",
          "glue:GetPartitionIndexes",
          "glue:GetTables"
        ]
        Resource = "*"
      },
      {
        Sid    = "LakeFormationAccess"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataAccess",
          "lakeformation:GrantPermissions"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSEncryptionAccess"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn
      },
      {
        Sid    = "DynamoDBAccess"
        Effect = "Allow"
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ]
        Resource = "arn:aws:dynamodb:*:*:table/data_quality_*"
      },
      {
        Sid    = "LakeFormationAccessForIceberg"
        Effect = "Allow"
        Action = [
          "lakeformation:GetDataLakeSettings",
          "lakeformation:GetResourceLakeFormationTags",
          "lakeformation:ListLakeFormationOptins",
          "lakeformation:ListResources"
        ]
        Resource = "*"
      }
    ]
  })
}

# Note: Lake Formation permissions managed by parent module
# IAM role has lakeformation:GetDataAccess and lakeformation:GrantPermissions

# Glue Job - Public API Raw → Staged
resource "aws_glue_job" "public_api_raw_to_staged" {
  name              = local.public_api_raw_to_staged_job
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 600   # 10 minutes
  max_retries       = 1

  command {
    name            = "glueetl"
    script_location = "s3://${var.datalake_bucket_name}/scripts/glue-jobs/public-api-raw-to-staged/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"              = "s3://${var.datalake_bucket_name}/temp/"
    "--job-bookmark-option"  = "job-bookmark-disable"
    "--disable-proxy-v2"     = "true"
    "--datalake_bucket"      = var.datalake_bucket_name
  }

  tags = merge(
    var.tags,
    {
      Name = local.public_api_raw_to_staged_job
    }
  )

  depends_on = [
    aws_iam_role_policy.glue_job_policy,
    aws_s3_object.public_api_raw_to_staged_script
  ]
}

# Glue Job - Public API Staged → Curated (Iceberg)
resource "aws_glue_job" "public_api_staged_to_curated" {
  name              = local.public_api_staged_to_curated_job
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 600   # 10 minutes
  max_retries       = 1

  command {
    name            = "glueetl"
    script_location = "s3://${var.datalake_bucket_name}/scripts/glue-jobs/public-api-staged-to-curated/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"              = "s3://${var.datalake_bucket_name}/temp/"
    "--job-bookmark-option"  = "job-bookmark-disable"
    "--disable-proxy-v2"     = "true"
    "--datalake_bucket"      = var.datalake_bucket_name
    "--glue_database"        = var.glue_database_name
    # Iceberg support for AWS Glue 5.0
    "--datalake_formats"     = "iceberg"
    "--enable-glue-datacatalog" = "true"
    # Spark Iceberg catalog configuration (consolidated into single --conf parameter)
    "--conf"                 = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://${var.datalake_bucket_name}/curated/ --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO"
  }

  tags = merge(
    var.tags,
    {
      Name = local.public_api_staged_to_curated_job
    }
  )

  depends_on = [
    aws_iam_role_policy.glue_job_policy,
    aws_s3_object.public_api_staged_to_curated_script
  ]
}

# Glue Job - Public API Data Quality Validation
resource "aws_glue_job" "public_api_data_quality" {
  name              = local.public_api_data_quality_job
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 600   # 10 minutes
  max_retries       = 1

  command {
    name            = "glueetl"
    script_location = "s3://${var.datalake_bucket_name}/scripts/glue-jobs/public-api-data-quality/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"              = "s3://${var.datalake_bucket_name}/temp/"
    "--job-bookmark-option"  = "job-bookmark-disable"
    "--disable-proxy-v2"     = "true"
    "--datalake_bucket"      = var.datalake_bucket_name
    "--glue_database"        = var.glue_database_name
  }

  tags = merge(
    var.tags,
    {
      Name = local.public_api_data_quality_job
    }
  )

  depends_on = [
    aws_iam_role_policy.glue_job_policy,
    aws_s3_object.public_api_data_quality_script
  ]
}

# Upload RDS Glue job scripts
resource "aws_s3_object" "rds_raw_to_staged_script" {
  bucket = var.datalake_bucket_name
  key    = "scripts/glue-jobs/rds-raw-to-staged/job.py"
  source = "${path.module}/../glue-jobs/rds-raw-to-staged/job.py"
  etag   = filemd5("${path.module}/../glue-jobs/rds-raw-to-staged/job.py")
  tags   = var.tags
}

resource "aws_s3_object" "rds_data_quality_script" {
  bucket = var.datalake_bucket_name
  key    = "scripts/glue-jobs/rds-data-quality/job.py"
  source = "${path.module}/../glue-jobs/rds-data-quality/job.py"
  etag   = filemd5("${path.module}/../glue-jobs/rds-data-quality/job.py")
  tags   = var.tags
}

resource "aws_s3_object" "rds_staged_to_curated_script" {
  bucket = var.datalake_bucket_name
  key    = "scripts/glue-jobs/rds-staged-to-curated/job.py"
  source = "${path.module}/../glue-jobs/rds-staged-to-curated/job.py"
  etag   = filemd5("${path.module}/../glue-jobs/rds-staged-to-curated/job.py")
  tags   = var.tags
}

# Glue Job - RDS Raw → Staged
resource "aws_glue_job" "rds_raw_to_staged" {
  name              = local.rds_raw_to_staged_job
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 600
  max_retries       = 1

  command {
    name            = "glueetl"
    script_location = "s3://${var.datalake_bucket_name}/scripts/glue-jobs/rds-raw-to-staged/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"              = "s3://${var.datalake_bucket_name}/temp/"
    "--job-bookmark-option"  = "job-bookmark-disable"
    "--disable-proxy-v2"     = "true"
    "--datalake_bucket"      = var.datalake_bucket_name
  }

  tags = merge(
    var.tags,
    { Name = local.rds_raw_to_staged_job }
  )

  depends_on = [
    aws_iam_role_policy.glue_job_policy,
    aws_s3_object.rds_raw_to_staged_script
  ]
}

# Glue Job - RDS Data Quality
resource "aws_glue_job" "rds_data_quality" {
  name              = local.rds_data_quality_job
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 600
  max_retries       = 1

  command {
    name            = "glueetl"
    script_location = "s3://${var.datalake_bucket_name}/scripts/glue-jobs/rds-data-quality/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"              = "s3://${var.datalake_bucket_name}/temp/"
    "--job-bookmark-option"  = "job-bookmark-disable"
    "--disable-proxy-v2"     = "true"
    "--datalake_bucket"      = var.datalake_bucket_name
    "--glue_database"        = var.glue_database_name
  }

  tags = merge(
    var.tags,
    { Name = local.rds_data_quality_job }
  )

  depends_on = [
    aws_iam_role_policy.glue_job_policy,
    aws_s3_object.rds_data_quality_script
  ]
}

# Glue Job - RDS Staged → Curated (Iceberg)
resource "aws_glue_job" "rds_staged_to_curated" {
  name              = local.rds_staged_to_curated_job
  role_arn          = aws_iam_role.glue_job_role.arn
  glue_version      = "5.0"
  worker_type       = "G.2X"
  number_of_workers = 2
  timeout           = 600
  max_retries       = 1

  command {
    name            = "glueetl"
    script_location = "s3://${var.datalake_bucket_name}/scripts/glue-jobs/rds-staged-to-curated/job.py"
    python_version  = "3"
  }

  default_arguments = {
    "--TempDir"                      = "s3://${var.datalake_bucket_name}/temp/"
    "--job-bookmark-option"          = "job-bookmark-disable"
    "--disable-proxy-v2"             = "true"
    "--datalake_bucket"              = var.datalake_bucket_name
    "--glue_database"                = var.glue_database_name
    "--datalake_formats"             = "iceberg"
    "--enable-glue-datacatalog"      = "true"
        "--conf"                         = "spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions --conf spark.sql.catalog.glue_catalog=org.apache.iceberg.spark.SparkCatalog --conf spark.sql.catalog.glue_catalog.warehouse=s3://${var.datalake_bucket_name}/curated/ --conf spark.sql.catalog.glue_catalog.catalog-impl=org.apache.iceberg.aws.glue.GlueCatalog --conf spark.sql.catalog.glue_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO --conf spark.sql.catalog.glue_catalog.default-namespace=${var.glue_database_name}"
  }

  tags = merge(
    var.tags,
    { Name = local.rds_staged_to_curated_job }
  )

  depends_on = [
    aws_iam_role_policy.glue_job_policy,
    aws_s3_object.rds_staged_to_curated_script
  ]
}

# Lake Formation permissions for Glue job role (Iceberg operations)
resource "aws_lakeformation_permissions" "glue_job_role_database" {
  principal   = aws_iam_role.glue_job_role.arn
  permissions = ["ALL"]
  database {
    name = var.glue_database_name
  }
}

resource "aws_lakeformation_permissions" "glue_job_role_default_describe" {
  principal   = aws_iam_role.glue_job_role.arn
  permissions = ["DESCRIBE"]
  database {
    name = "default"
  }
}

resource "aws_lakeformation_permissions" "glue_job_role_data_location" {
  principal   = aws_iam_role.glue_job_role.arn
  permissions = ["DATA_LOCATION_ACCESS"]
  data_location {
    arn = "arn:aws:s3:::${var.datalake_bucket_name}"
  }
}
