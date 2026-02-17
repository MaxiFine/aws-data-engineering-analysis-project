#terraform {
#  required_version = ">= 1.0"
#  required_providers {
#    aws = {
#      source  = "hashicorp/aws"
#      version = "~> 5.0"
#    }
#    random = {
#      source  = "hashicorp/random"
#      version = "~> 3.5"
#    }
#  }
#}

# Provider configuration commented out - inherited from parent module
# This allows the module to be called with depends_on from the parent
# provider "aws" {
#   region = var.aws_region
#
#   default_tags {
#     tags = {
#       ManagedBy = "Terraform"
#       Module    = "data-bi-lakehouse"
#     }
#   }
# }
