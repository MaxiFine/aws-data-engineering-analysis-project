# IAM Role for Step Functions
resource "aws_iam_role" "step_functions_role" {
  name = "${var.resource_prefix}-step-functions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "states.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Step Functions - Full access for all services
resource "aws_iam_role_policy" "step_functions_policy" {
  name = "${var.resource_prefix}-step-functions-policy"
  role = aws_iam_role.step_functions_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllActionsAllServices"
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      }
    ]
  })
}

# Step Functions State Machine
resource "aws_sfn_state_machine" "lakehouse_orchestration" {
  name       = "${var.resource_prefix}-orchestration"
  role_arn   = aws_iam_role.step_functions_role.arn
  definition = templatefile("${path.module}/state_machine.json", {
    public_api_raw_to_staged      = var.glue_job_names.public_api_raw_to_staged
    public_api_data_quality       = var.glue_job_names.public_api_data_quality
    public_api_staged_to_curated  = var.glue_job_names.public_api_staged_to_curated
    rds_raw_to_staged             = var.glue_job_names.rds_raw_to_staged
    rds_data_quality              = var.glue_job_names.rds_data_quality
    rds_staged_to_curated         = var.glue_job_names.rds_staged_to_curated
    datalake_bucket               = var.datalake_bucket_name
    glue_database                 = var.glue_database_name
  })

  tags = var.tags

  depends_on = [aws_iam_role_policy.step_functions_policy]
}

# CloudWatch Log Group for Step Functions
resource "aws_cloudwatch_log_group" "step_functions_logs" {
  name              = "/aws/states/${var.resource_prefix}-orchestration"
  retention_in_days = 30

  tags = var.tags
}

# Master State Machine - Orchestrates Lambda + DMS (parallel) → Child ETL
resource "aws_sfn_state_machine" "master_orchestration" {
  name       = "${var.resource_prefix}-master-orchestration"
  role_arn   = aws_iam_role.step_functions_role.arn
  definition = templatefile("${path.module}/master_state_machine.json", {
    lambda_function_arn        = var.lambda_function_arn
    dms_replication_config_arn = var.dms_replication_config_arn
    child_state_machine_arn    = aws_sfn_state_machine.lakehouse_orchestration.arn
  })

  tags = var.tags

  depends_on = [aws_iam_role_policy.step_functions_policy]
}

# EventBridge Rule for scheduled trigger
resource "aws_cloudwatch_event_rule" "lakehouse_schedule" {
  name                = "${var.resource_prefix}-schedule"
  description         = "Daily trigger for data lakehouse complete orchestration (ingest + ETL)"
  schedule_expression = var.schedule_time
  state               = var.enable_schedule ? "ENABLED" : "DISABLED"

  tags = var.tags
}

# EventBridge Target - Master Step Functions (instead of child)
resource "aws_cloudwatch_event_target" "step_functions_target" {
  rule      = aws_cloudwatch_event_rule.lakehouse_schedule.name
  target_id = "MasterLakehouseOrchestration"
  arn       = aws_sfn_state_machine.master_orchestration.arn
  role_arn  = aws_iam_role.eventbridge_role.arn

  depends_on = [aws_iam_role_policy.eventbridge_policy, aws_sfn_state_machine.master_orchestration]
}

# IAM Role for EventBridge
resource "aws_iam_role" "eventbridge_role" {
  name = "${var.resource_prefix}-eventbridge-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "events.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for EventBridge - Full permissions
resource "aws_iam_role_policy" "eventbridge_policy" {
  name = "${var.resource_prefix}-eventbridge-policy"
  role = aws_iam_role.eventbridge_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllActionsAllServices"
        Effect = "Allow"
        Action = "*"
        Resource = "*"
      }
    ]
  })
}
