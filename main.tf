provider "aws" {
  region = var.region
}

terraform {
  backend "s3" {
    bucket = "pass-tf-state-bucket"
    key    = "product-initial-fetch-state"
    region = "ap-south-1"
    # You can also specify other backend configurations, such as encrypting the state file.
  }
}



module "sqs_lambda" {
  source = "./modules/sqs_lambda"
  region       = var.region
  sqs_queue_name     = var.sqs_queue_name
  lambda_role_name   = var.lambda_role_name
  iam_role_name      = var.iam_role_name
  # iam_policy_name    = var.iam_policy_name
  iam_api_policy_name = var.iam_api_policy_name
  lambda_iam_policy_name = var.lambda_iam_policy_name
  api_gateway_name   = var.api_gateway_name
  api_gateway_description  = var.api_gateway_description
  api_gateway_stage_name   = var.api_gateway_stage_name
}
