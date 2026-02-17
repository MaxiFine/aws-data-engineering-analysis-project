# Generate random suffix for unique resource naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

locals {
  resource_prefix = "${var.project_name}-${var.environment}-${random_string.suffix.result}"
}

# Module 0: Governance - Lake Formation service role (created first)
module "governance" {
  source          = "./modules/governance"
  resource_prefix = local.resource_prefix
  tags            = var.tags
}

# Module 1: Security - KMS encryption key
module "security" {
  source           = "./modules/security"
  resource_prefix  = local.resource_prefix
  principal_org_id = var.principal_org_id
  tags             = var.tags

  depends_on = [module.governance]
}

# Module 2: Storage - S3 data lake with three-tier structure
module "storage" {
  source           = "./modules/storage"
  resource_prefix  = local.resource_prefix
  kms_key_arn      = module.security.kms_key_arn
  principal_org_id = var.principal_org_id
  tags             = var.tags

  depends_on = [module.security, module.governance]
}

# Module 3: Catalog - Glue database for Iceberg table metadata
module "catalog" {
  source             = "./modules/catalog"
  resource_prefix    = local.resource_prefix
  datalake_bucket_name = module.storage.datalake_bucket_name
  tags               = var.tags

  depends_on = [module.storage]
}

# Module 4: Query - Athena v3 workgroup for SQL queries on Iceberg
module "query" {
  source          = "./modules/query"
  resource_prefix = local.resource_prefix
  glue_database   = module.catalog.glue_database_name
  kms_key_arn     = module.security.kms_key_arn
  tags            = var.tags

  depends_on = [module.security, module.catalog]
}

# Module 5: IAM - Roles for ETL, Analyst, ML teams
module "iam" {
  source                   = "./modules/iam"
  datalake_bucket_arn      = module.storage.datalake_bucket_arn
  athena_results_bucket_arn = module.query.athena_results_bucket_arn
  kms_key_arn              = module.security.kms_key_arn
  tags                     = var.tags

  depends_on = [module.storage, module.query, module.security]
}

# Module 6: Lake Formation - Access control & governance with tag-based policies
module "lakeformation" {
  source                = "./modules/lakeformation"
  resource_prefix       = local.resource_prefix
  datalake_bucket_arn   = module.storage.datalake_bucket_arn
  glue_database_name    = module.catalog.glue_database_name
  lf_service_role_arn   = module.governance.lakeformation_service_role_arn
  admin_principals      = ["arn:aws:iam::517798689069:user/frank-aws-starter-profile"]
  tags                  = var.tags

  depends_on = [module.storage, module.catalog, module.governance, module.iam]
}

# Module 7: ETL - Glue jobs for data ingestion
module "etl" {
  source = "./etl-templates/terraform"

  resource_prefix      = local.resource_prefix
  datalake_bucket_name = module.storage.datalake_bucket_name
  glue_database_name   = module.catalog.glue_database_name
  kms_key_arn          = module.security.kms_key_arn
  tags                 = var.tags

  depends_on = [module.storage, module.catalog, module.security]
}

# Module 8: Data Sources - Lambda + DMS for ingestion
module "data_sources" {
  source = "./data-sources"

  vpc_id                  = var.vpc_id
  private_route_table_ids = var.private_route_table_ids
  replication_instance_sgs = var.replication_instance_sgs
  private_subnet_ids      = var.private_subnet_ids

  target_s3_bucket_name = module.storage.datalake_bucket_name
  data_sources_config   = var.data_sources_config
  data_format           = var.data_format
  compression_type      = var.compression_type
  migration_type        = var.migration_type
  kms_key_id            = module.security.kms_key_arn
  lambda_function_name  = "${local.resource_prefix}-${var.lambda_function_name}"
  existing_dms_vpc_role_arn = var.existing_dms_vpc_role_arn 

  tags = var.tags

  depends_on = [module.storage, module.security]
}

# Module 9: Step Functions for orchestration of ETL
module "orchestration" {
  source = "./modules/orchestration"

  resource_prefix            = local.resource_prefix
  datalake_bucket_name       = module.storage.datalake_bucket_name
  glue_database_name         = module.catalog.glue_database_name
  lambda_function_arn        = module.data_sources.lambda_function_arn
  dms_replication_config_arn = module.data_sources.dms_primary_replication_config_arn
  glue_job_names = {
    public_api_raw_to_staged      = module.etl.public_api_raw_to_staged_job_name
    public_api_data_quality       = module.etl.public_api_data_quality_job_name
    public_api_staged_to_curated  = module.etl.public_api_staged_to_curated_job_name
    rds_raw_to_staged             = module.etl.rds_raw_to_staged_job_name
    rds_data_quality              = module.etl.rds_data_quality_job_name
    rds_staged_to_curated         = module.etl.rds_staged_to_curated_job_name
  }
  tags = var.tags

  depends_on = [module.etl, module.data_sources]
}


#NOTE: The Analysis module must be deployed separately after the Lakehouse is set up and data is available in Athena.
# The etl orchestration does not run immediately to make the tables (schemas) available for analysis.

# Module 10: Analysis - QuickSight for data analysis (athena integration)
# module "analysis" {
#   source = "./analytics"

#   quicksight_subscription = var.quicksight_subscription # Optional QuickSight subscription configuration (Only specify if account doesn't have QuickSight subscription)

#   athena_datasource_name = var.athena_datasource_name
#   athena_workgroup_name  = module.query.athena_workgroup_name
#   glue_database_name     = module.catalog.glue_database_name
#   glue_table_name        = var.glue_table_name

#   athena_dataset = var.athena_dataset

#   tags = var.tags

#   depends_on = [module.orchestration]
# }
