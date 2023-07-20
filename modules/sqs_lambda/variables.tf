variable "region" {
  description = "The AWS region where resources will be created."
  type        = string
  default = "ap-south-1"
}

variable "sqs_queue_name" {
  description = "The name of the SQS queue to create."
  type        = string
}

variable "lambda_role_name" {
  description = "The name of the IAM role for the Lambda function."
  type        = string
}

variable "iam_role_name" {
  description = "The name of the IAM role for the API Gateway."
  type        = string
}

variable "iam_policy_name" {
  description = "The name of the IAM policy for the API Gateway."
  type        = string
}

variable "api_gateway_name" {
  description = "The name of the API Gateway."
  type        = string
}

variable "api_gateway_description" {
  description = "The description of the API Gateway."
  type        = string
}

variable "api_gateway_stage_name" {
  description = "The name of the API Gateway stage."
  type        = string
}
