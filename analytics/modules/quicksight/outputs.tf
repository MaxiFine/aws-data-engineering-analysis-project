# ============================================================================
# QuickSight Module Outputs
# ============================================================================

output "dashboard_url" {
  description = "URL of the QuickSight dashboard"
  value       = "https://${data.aws_region.current.id}.quicksight.aws.amazon.com/sn/dashboards/${aws_quicksight_dashboard.athena.dashboard_id}"
}

output "analysis_arn" {
  description = "ARN of the QuickSight analysis"
  value       = aws_quicksight_analysis.athena.arn
}

output "dataset_arn" {
  description = "ARN of the QuickSight dataset"
  value       = aws_quicksight_data_set.athena.arn
}

output "datasource_arn" {
  description = "ARN of the QuickSight data source"
  value       = aws_quicksight_data_source.athena.arn
}