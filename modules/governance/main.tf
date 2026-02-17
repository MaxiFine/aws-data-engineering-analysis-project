# Custom service role for Lake Formation data access
resource "aws_iam_role" "lakeformation_service_role" {
  name = "CustomServiceRoleForLakeFormationDataAccess_${var.resource_prefix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lakeformation.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Attach policy allowing S3 and Glue operations
resource "aws_iam_role_policy" "lakeformation_service_policy" {
  name   = "LakeFormationServicePolicy"
  role   = aws_iam_role.lakeformation_service_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetBucketLocation",
          "s3:ListBucketVersions"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "glue:GetDatabase",
          "glue:GetTable",
          "glue:GetPartitions",
          "glue:CreateTable",
          "glue:UpdateTable",
          "glue:DeleteTable",
          "glue:BatchCreatePartition",
          "glue:BatchDeletePartition",
          "glue:GetDatabases",
          "glue:GetTables",
          "glue:GetTableVersions"
        ]
        Resource = "*"
      }
    ]
  })
}
