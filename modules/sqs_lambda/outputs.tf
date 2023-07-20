output "created_resources" {
  value = {
    "sqs_queue_arn"   = aws_sqs_queue.queue.arn,
    "iam_role_arn"    = aws_iam_role.api.arn,
    "api_gateway_arn" = aws_api_gateway_rest_api.api.arn,
    # "request_validator_arn"   = aws_api_gateway_request_validator.api.id,
    "integration_uri" = aws_api_gateway_integration.api.uri,
  }
}
