###################################################
# Lambda Function Outputs
###################################################

# ARN of the Lambda function
output "lambda_function_arn" {
  description = "ARN of the Lambda function"
  value       = module.cms_ingest_lambda.lambda_function_arn
}