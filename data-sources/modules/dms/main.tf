
###################################################
# IAM Role for DMS to manage VPC
###################################################


# Fetch the active provider region and caller id
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Generate a random suffix for resource names to avoid conflicts
resource "random_id" "suffix" {
  byte_length = 4
}


# Fetch existing DMS VPC role if provided, otherwise create new one
data "aws_iam_role" "existing_dms_vpc_role" {
  count = var.existing_dms_vpc_role_arn != null ? 1 : 0
  name  = "dms-vpc-role"
}

data "aws_iam_policy_document" "dms_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      identifiers = ["dms.amazonaws.com"]
      type        = "Service"
    }
  }
}

# Create new DMS VPC role only if existing one is not provided
resource "aws_iam_role" "dms-vpc-role" {
  count              = var.existing_dms_vpc_role_arn == null ? 1 : 0
  assume_role_policy = data.aws_iam_policy_document.dms_assume_role.json
  name               = "dms-vpc-role"
  tags               = var.tags
}

# Attach policy to new role if created, otherwise use existing role
resource "aws_iam_role_policy_attachment" "dms-vpc-role-AmazonDMSVPCManagementRole" {
  count      = var.existing_dms_vpc_role_arn == null ? 1 : 0
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonDMSVPCManagementRole"
  role       = aws_iam_role.dms-vpc-role[0].name
}

# Local for DMS VPC role (either existing or newly created)
locals {
  dms_vpc_role_arn  = var.existing_dms_vpc_role_arn != null ? var.existing_dms_vpc_role_arn : aws_iam_role.dms-vpc-role[0].arn
  dms_vpc_role_name = var.existing_dms_vpc_role_arn != null ? data.aws_iam_role.existing_dms_vpc_role[0].name : aws_iam_role.dms-vpc-role[0].name
}


###################################################
# Replication subnet group
###################################################

resource "aws_dms_replication_subnet_group" "dms-subnet-group" {
  replication_subnet_group_description = "Private subnets for DMS replication instance"
  replication_subnet_group_id          = "dms-subnet-group-${random_id.suffix.hex}"

  subnet_ids = var.private_subnet_ids

  # implicit dependencies via locals reference (both new and existing role paths)
  # the local.dms_vpc_role_name depends on either the new or existing role
  tags = var.tags
}

# Ensure role is properly set up before subnet group
# This implicitly depends on dms_vpc_role_name local which includes all role dependencies
resource "null_resource" "dms_role_ready" {
  count = 1

  provisioner "local-exec" {
    command = "echo 'DMS VPC role ready: ${local.dms_vpc_role_name}'"
  }

  triggers = {
    role_arn = local.dms_vpc_role_arn
  }
}

# Make subnet group depend on role readiness
resource "null_resource" "subnet_group_ready" {
  depends_on = [
    aws_dms_replication_subnet_group.dms-subnet-group,
    null_resource.dms_role_ready
  ]
}


###################################################
#  IAM Role for DMS to write to S3
###################################################

resource "aws_iam_role" "dms_s3_access" {
  name = "dms-s3-access-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "dms.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "dms_s3_policy" {
  name = "dms-s3-policy-${random_id.suffix.hex}"
  role = aws_iam_role.dms_s3_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:PutObjectTagging"
      ]
      Resource = [
        "arn:aws:s3:::${var.target_s3_bucket_name}/*"
      ]
      },
      {
        "Effect" : "Allow",
        "Action" : [
          "s3:ListBucket"
        ],
        "Resource" : [
          "arn:aws:s3:::${var.target_s3_bucket_name}"
        ]
      }
    ]
  })
}


#########################################################
#  IAM Role for DMS to retrieve secrets in Secret Manager
#########################################################

resource "aws_iam_role" "dms_sm_access_role" {
  name = "dms-access-role-${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "dms.${data.aws_region.current.id}.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "dms_secret_access_policy" {
  role = aws_iam_role.dms_sm_access_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = "arn:aws:secretsmanager:${data.aws_region.current.id}:${data.aws_caller_identity.current.account_id}:secret:*"
      },
      {
        Effect   = "Allow"
        Action   = "iam:PassRole"
        Resource = "*"
      }
    ]
  })
}


###################################################
# Source Endpoint 
###################################################

resource "aws_dms_endpoint" "sources" {
  for_each = { for ds in var.data_sources_config : ds.name => ds }

  endpoint_id   = "${each.key}-source-${random_id.suffix.hex}"
  endpoint_type = "source"
  engine_name   = each.value.engine_name
  database_name = each.value.database_name

  ssl_mode = each.value.ssl_mode

  # Use Secrets Manager
  secrets_manager_access_role_arn = aws_iam_role.dms_sm_access_role.arn
  secrets_manager_arn             = each.value.secrets_manager_arn

  tags = var.tags
}


###################################################
# Target Endpoint (S3)
###################################################

resource "aws_dms_s3_endpoint" "targets" {
  for_each = { for ds in var.data_sources_config : ds.name => ds }

  endpoint_id             = "${each.key}-s3-target-${random_id.suffix.hex}"
  endpoint_type           = "target"
  bucket_name             = var.target_s3_bucket_name
  bucket_folder           = each.value.s3_prefix
  service_access_role_arn = aws_iam_role.dms_s3_access.arn
  data_format             = var.data_format
  compression_type        = var.compression_type

  tags = var.tags
}


# Create a VPC Endpoint for Amazon S3
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = var.vpc_id
  service_name      = "com.amazonaws.${data.aws_region.current.id}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = var.private_route_table_ids

  lifecycle {
    ignore_changes = [route_table_ids]
  }

  tags = merge(
    var.tags,
    {
      Name = "dms-s3-vpc-endpoint-${random_id.suffix.hex}"
    }
  )
}

# Create security group for Secrets Manager VPC endpoint
resource "aws_security_group" "secretsmanager_endpoint_sg" {
  name_prefix = "secretsmanager-endpoint-sg-${random_id.suffix.hex}"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTPS from DMS replication instance"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    # DMS replication instance security group ID
    security_groups = var.replication_instance_sgs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "secretsmanager-sg-${random_id.suffix.hex}"
    }
  )
}

resource "aws_vpc_endpoint" "secretsmanager" {
  vpc_id              = var.vpc_id
  service_name        = "com.amazonaws.${data.aws_region.current.id}.secretsmanager"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = var.private_subnet_ids
  security_group_ids  = [aws_security_group.secretsmanager_endpoint_sg.id]
  private_dns_enabled = false

  lifecycle {
    ignore_changes = [private_dns_enabled]
  }

  tags = merge(
    var.tags,
    {
      Name = "secretsmanager-${random_id.suffix.hex}"
    }
  )
}


###################################################
# 6. Replication configuration (serverless)
###################################################

resource "aws_dms_replication_config" "name" {

  for_each = { for ds in var.data_sources_config : ds.name => ds }

  replication_config_identifier = "${each.key}-repli-conf-${random_id.suffix.hex}"
  resource_identifier           = "${each.key}-repli-res-${random_id.suffix.hex}"
  replication_type              = var.migration_type
  source_endpoint_arn           = aws_dms_endpoint.sources[each.key].endpoint_arn
  target_endpoint_arn           = aws_dms_s3_endpoint.targets[each.key].endpoint_arn
  table_mappings = jsonencode({
    rules = [
      {
        "rule-type" = "selection"
        "rule-id"   = "1"
        "rule-name" = "include_all_tables"
        "object-locator" = {
          "schema-name" = "%"
          "table-name"  = "%"
        }
        "rule-action" = "include"
      }
    ]
  })

  start_replication = true

  compute_config {
    replication_subnet_group_id = aws_dms_replication_subnet_group.dms-subnet-group.id
    max_capacity_units          = "64"
    min_capacity_units          = "2"
    vpc_security_group_ids      = var.replication_instance_sgs
    kms_key_id                  = var.kms_key_id # ARN format: arn:aws:kms:region:account:key/id
    # preferred_maintenance_window = "sun:23:45-mon:00:30"
  }

  tags = var.tags
}
