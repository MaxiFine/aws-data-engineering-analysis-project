# This file will be created after Glue jobs are deployed
# It will reference the Glue job outputs from glue-jobs.tf

# Placeholder for orchestration outputs
output "glue_jobs_for_orchestration" {
  description = "Job names for orchestration"
  value = {
    public_api_raw_to_staged      = aws_glue_job.public_api_raw_to_staged.name
    public_api_data_quality       = aws_glue_job.public_api_data_quality.name
    public_api_staged_to_curated  = aws_glue_job.public_api_staged_to_curated.name
    rds_raw_to_staged             = aws_glue_job.rds_raw_to_staged.name
    rds_data_quality              = aws_glue_job.rds_data_quality.name
    rds_staged_to_curated         = aws_glue_job.rds_staged_to_curated.name
  }
}
