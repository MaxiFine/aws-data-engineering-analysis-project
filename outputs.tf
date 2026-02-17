output "random_suffix" {
  value       = random_string.suffix.result
  description = "Random suffix used for all resource names"
}

output "lakeformation_service_role_arn" {
  value       = module.governance.lakeformation_service_role_arn
  description = "Lake Formation custom service role ARN"
}

output "kms_key_id" {
  value       = module.security.kms_key_id
  description = "KMS key ID for encryption"
}

output "kms_key_arn" {
  value       = module.security.kms_key_arn
  description = "KMS key ARN"
}

output "datalake_bucket_name" {
  value       = module.storage.datalake_bucket_name
  description = "Primary S3 data lake bucket"
}

output "datalake_bucket_arn" {
  value       = module.storage.datalake_bucket_arn
  description = "Data lake bucket ARN"
}

output "glue_database_name" {
  value       = module.catalog.glue_database_name
  description = "Glue catalog database name"
}

output "glue_database_arn" {
  value       = module.catalog.glue_database_arn
  description = "Glue database ARN"
}

output "athena_workgroup_name" {
  value       = module.query.athena_workgroup_name
  description = "Athena workgroup name for Iceberg queries"
}

output "athena_results_bucket" {
  value       = module.query.athena_results_bucket
  description = "S3 bucket for Athena query results"
}

output "etl_role_arn" {
  value       = module.iam.etl_role_arn
  description = "ETL role ARN"
}

output "analyst_role_arn" {
  value       = module.iam.analyst_role_arn
  description = "Analyst role ARN"
}

output "ml_role_arn" {
  value       = module.iam.ml_role_arn
  description = "ML role ARN"
}

output "sensitivity_tag_values" {
  value       = module.lakeformation.sensitivity_tag_values
  description = "Lake Formation sensitivity tag values"
}

output "domain_tag_values" {
  value       = module.lakeformation.domain_tag_values
  description = "Lake Formation domain tag values"
}

output "public_api_raw_to_staged_job_name" {
  value       = module.etl.public_api_raw_to_staged_job_name
  description = "Public API Raw to Staged Glue job name"
}

output "public_api_staged_to_curated_job_name" {
  value       = module.etl.public_api_staged_to_curated_job_name
  description = "Public API Staged to Curated Glue job name"
}

output "glue_job_role_arn" {
  value       = module.etl.glue_job_role_arn
  description = "Glue job IAM role ARN"
}

output "master_state_machine_arn" {
  value       = module.orchestration.master_state_machine_arn
  description = "Master Step Functions state machine ARN (Lambda + DMS + ETL)"
}

output "master_state_machine_name" {
  value       = module.orchestration.master_state_machine_name
  description = "Master Step Functions state machine name"
}

output "child_state_machine_arn" {
  value       = module.orchestration.child_state_machine_arn
  description = "Child Step Functions state machine ARN (ETL only)"
}

output "child_state_machine_name" {
  value       = module.orchestration.child_state_machine_name
  description = "Child Step Functions state machine name"
}

output "eventbridge_rule_name" {
  value       = module.orchestration.eventbridge_rule_name
  description = "EventBridge rule name for daily orchestration trigger"
}

output "manual_trigger_master" {
  value       = module.orchestration.manual_trigger_master
  description = "AWS CLI command to manually trigger master orchestration"
}

output "manual_trigger_child" {
  value       = module.orchestration.manual_trigger_child
  description = "AWS CLI command to manually trigger child orchestration (ETL only)"
}

#NOTE: The Analysis module must be deployed separately after the Lakehouse is set up and data is available in Athena.
# The etl orchestration does not run immediately to make the tables (schemas) available for analysis.

# output "quicksight_dashboard_url" {
#   value       = module.analysis.dashboard_url
#   description = "URL of the QuickSight dashboard"
# }