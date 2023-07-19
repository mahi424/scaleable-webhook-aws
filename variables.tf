variable "region" {
  type    = string
  default = "us-east-1" # Replace with your desired region
}

variable "account_id" {
  type = string
}

variable "sqs_queue_name" {
  type    = string
  default = "sqs-queue"
}

variable "iam_role_name" {
  type    = string
  default = "api-role"
}

variable "api_gateway_name" {
  type    = string
  default = "api"
}

variable "api_gateway_description" {
  type    = string
  default = "POST records to SQS queue"
}

variable "api_gateway_stage_name" {
  type    = string
  default = "main"
}


variable "iam_policy_name" {
  type    = string
  default = "api-perms"
}


variable "state_file_path" {
  type    = string
  default = "webhook-state-file"
}


