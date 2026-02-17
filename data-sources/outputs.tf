###################################################
# Data Sources Outputs
###################################################

# Lambda outputs
output "lambda_function_arn" {
  description = "ARN of the Lambda function for public API ingestion"
  value       = module.lambda.lambda_function_arn
}

# DMS outputs - Replication configurations (Serverless)
output "dms_replication_config_arns" {
  description = "ARNs of DMS replication configurations"
  value       = module.dms.dms_replication_config_arns
}

output "dms_replication_config_identifiers" {
  description = "Identifiers of DMS replication configurations"
  value       = module.dms.dms_replication_config_identifiers
}

# Primary DMS replication config for orchestration (use postgres config if available)
output "dms_primary_replication_config_arn" {
  description = "Primary DMS replication configuration ARN for orchestration (RDS PostgreSQL)"
  value       = try(module.dms.dms_replication_config_arns["postgres"], values(module.dms.dms_replication_config_arns)[0])
}

# DMS Endpoints
output "dms_source_endpoints" {
  description = "Map of DMS source endpoint ARNs"
  value       = module.dms.dms_source_endpoints
}

output "dms_target_endpoints" {
  description = "Map of DMS target S3 endpoint ARNs"
  value       = module.dms.dms_target_endpoints
}
