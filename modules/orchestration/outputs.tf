output "master_state_machine_arn" {
  description = "ARN of the Master Step Functions state machine (ingest + ETL orchestration)"
  value       = aws_sfn_state_machine.master_orchestration.arn
}

output "master_state_machine_name" {
  description = "Name of the Master Step Functions state machine"
  value       = aws_sfn_state_machine.master_orchestration.name
}

output "child_state_machine_arn" {
  description = "ARN of the Child Step Functions state machine (ETL transformation only)"
  value       = aws_sfn_state_machine.lakehouse_orchestration.arn
}

output "child_state_machine_name" {
  description = "Name of the Child Step Functions state machine"
  value       = aws_sfn_state_machine.lakehouse_orchestration.name
}

output "eventbridge_rule_arn" {
  description = "ARN of the EventBridge rule for scheduling"
  value       = aws_cloudwatch_event_rule.lakehouse_schedule.arn
}

output "eventbridge_rule_name" {
  description = "Name of the EventBridge rule"
  value       = aws_cloudwatch_event_rule.lakehouse_schedule.name
}

output "step_functions_role_arn" {
  description = "ARN of the IAM role for Step Functions"
  value       = aws_iam_role.step_functions_role.arn
}

output "manual_trigger_master" {
  description = "AWS CLI command to manually trigger MASTER orchestration (Lambda + DMS + ETL)"
  value       = "aws stepfunctions start-execution --state-machine-arn ${aws_sfn_state_machine.master_orchestration.arn} --region eu-west-1"
}

output "manual_trigger_child" {
  description = "AWS CLI command to manually trigger CHILD orchestration (ETL only, skip ingest)"
  value       = "aws stepfunctions start-execution --state-machine-arn ${aws_sfn_state_machine.lakehouse_orchestration.arn} --region eu-west-1"
}
