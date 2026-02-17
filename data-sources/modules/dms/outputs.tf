###################################################
# Outputs for DMS Infrastructure
###################################################


###################################################
# DMS Endpoints
###################################################

output "dms_source_endpoints" {
  description = "Map of DMS source endpoint ARNs"
  value = {
    for k, v in aws_dms_endpoint.sources : k => v.endpoint_arn
  }
}

output "dms_target_endpoints" {
  description = "Map of DMS target S3 endpoint ARNs"
  value = {
    for k, v in aws_dms_s3_endpoint.targets : k => v.endpoint_arn
  }
}

###################################################
# DMS Replication Configurations (Serverless)
###################################################

output "dms_replication_config_ids" {
  description = "IDs of the DMS replication configurations"
  value = {
    for k, v in aws_dms_replication_config.name : k => v.id
  }
}

output "dms_replication_config_arns" {
  description = "ARNs of the DMS replication configurations"
  value = {
    for k, v in aws_dms_replication_config.name : k => v.arn
  }
}

output "dms_replication_config_identifiers" {
  description = "Identifiers of the DMS replication configurations"
  value = {
    for k, v in aws_dms_replication_config.name : k => v.replication_config_identifier
  }
}

###################################################
# VPC Endpoints
###################################################

output "s3_vpc_endpoint_id" {
  description = "ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "secretsmanager_endpoint_id" {
  description = "ID of the Secrets Manager VPC endpoint"
  value       = aws_vpc_endpoint.secretsmanager.id
}