terraform {

  backend "s3" {
    bucket       = "account-vending-terraform-state"
    key          = "data-bi/quicksight/terraform.tfstate"
    region       = "eu-west-1"
    use_lockfile = true
  }
}