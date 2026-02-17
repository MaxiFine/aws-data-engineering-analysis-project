# ============================================================================
# Analytics Outputs
# ============================================================================

output "dashboard_url" {
  description = "URL of the QuickSight dashboard"
  value       = module.quicksight.dashboard_url
}

output "analysis_arn" {
  description = "ARN of the QuickSight analysis"
  value       = module.quicksight.analysis_arn
}

output "dataset_arn" {
  description = "ARN of the QuickSight dataset"
  value       = module.quicksight.dataset_arn
}

output "datasource_arn" {
  description = "ARN of the QuickSight data source"
  value       = module.quicksight.datasource_arn
}

