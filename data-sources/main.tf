
module "dms" {
  source = "./modules/dms"

  vpc_id                  = var.vpc_id
  private_route_table_ids = var.private_route_table_ids
  replication_instance_sgs = var.replication_instance_sgs
  private_subnet_ids      = var.private_subnet_ids

  target_s3_bucket_name = var.target_s3_bucket_name

  data_sources_config = var.data_sources_config

  data_format = var.data_format

  compression_type = var.compression_type

  migration_type = var.migration_type

  kms_key_id = var.kms_key_id
  
  existing_dms_vpc_role_arn = var.existing_dms_vpc_role_arn

  tags = var.tags
}

module "lambda" {
  source               = "./modules/public_api"
  lambda_function_name = var.lambda_function_name
  s3_bucket_name       = var.target_s3_bucket_name

  tags = var.tags
}
