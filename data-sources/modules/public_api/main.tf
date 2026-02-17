
module "cms_ingest_lambda" {
  source  = "terraform-aws-modules/lambda/aws"
  version = "~> 7.0"

  function_name = var.lambda_function_name
  description   = "Fetch CMS datasets by year, convert to CSV, and upload to S3"
  handler       = "main.lambda_handler"
  runtime       = "python3.12"
  architectures = ["arm64"]
  timeout       = 900
  memory_size   = 1024

  # Source code from directory
  source_path = "${path.module}/lambda_function"

  # AWS Lambda Layer for pandas and AWS SDK
  layers = [
    "arn:aws:lambda:eu-west-1:336392948345:layer:AWSSDKPandas-Python312:13"
  ]

  create_role                   = true
  attach_cloudwatch_logs_policy = true
  role_name                     = "cms-ingest-lambda-role"

  attach_policy_statements = true
  policy_statements = [
    {
      actions = [
        "s3:PutObject",
        "s3:PutObjectAcl",
        "s3:GetObject",
        "s3:ListBucket"
      ]
      resources = [
        "arn:aws:s3:::${var.s3_bucket_name}",
        "arn:aws:s3:::${var.s3_bucket_name}/*"
      ]
      effect = "Allow"
      sid    = "S3WriteAccessForCMSData"
    },
    {
      actions = [
        "kms:Decrypt",
        "kms:GenerateDataKey",
        "kms:DescribeKey"
      ]
      resources = ["*"]
      effect    = "Allow"
      sid       = "KMSEncryptionAccess"
    }
  ]

  environment_variables = {
    BUCKET_NAME = var.s3_bucket_name
  }

  tags = merge(
    var.tags,
    {
      Name = "cms-ingest-lambda"
    }
  )
}
