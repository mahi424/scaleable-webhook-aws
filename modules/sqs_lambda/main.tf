locals {
  lambda_folder_path = "modules/sqs_lambda/forward_to_sqs_lambda"
}

data "archive_file" "forward_to_sqs_lambda" {
  type        = "zip"
  source_dir  = local.lambda_folder_path
  output_path = "${local.lambda_folder_path}.zip"
}

resource "aws_sqs_queue" "queue" {
  name                      = var.sqs_queue_name
  delay_seconds             = 0      // how long to delay delivery of records
  max_message_size          = 262144 // = 256KiB, which is the limit set by AWS
  message_retention_seconds = 86400  // = 1 day in seconds
  receive_wait_time_seconds = 10     // how long to wait for a record to stream in when ReceiveMessage is called
}

resource "aws_lambda_function" "forward_to_sqs" {
  function_name    = "forward_to_sqs_lambda"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  filename         = data.archive_file.forward_to_sqs_lambda.output_path
  source_code_hash = filebase64sha256(data.archive_file.forward_to_sqs_lambda.output_path)

  environment {
    variables = {
      QueueUrl = aws_sqs_queue.queue.id
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = var.lambda_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda" {
  name = var.lambda_iam_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.queue.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

resource "aws_iam_role" "api" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Effect = "Allow"
        "Sid"  = ""
      },
    ]
  })
}

resource "aws_iam_policy" "api" {
  name = var.iam_api_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sqs:GetQueueUrl",
          "sqs:ChangeMessageVisibility",
          "sqs:SendMessage",
          "sqs:GetQueueAttributes",
        ]
        Resource = aws_sqs_queue.queue.arn
      },
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api" {
  role       = aws_iam_role.api.name
  policy_arn = aws_iam_policy.api.arn
}

resource "aws_api_gateway_rest_api" "api" {
  name        = var.api_gateway_name
  description = var.api_gateway_description
}

resource "aws_api_gateway_method" "api" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_rest_api.api.root_resource_id
  api_key_required = false
  http_method      = "POST"
  authorization    = "NONE"
}

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = "POST"
  type                    = "AWS_PROXY" # Use AWS_PROXY for Lambda integration
  integration_http_method = "POST"
  passthrough_behavior    = "WHEN_NO_MATCH"
  uri                     = aws_lambda_function.forward_to_sqs.invoke_arn

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.forward_to_sqs.function_name
  principal     = "apigateway.amazonaws.com"
}

resource "aws_api_gateway_integration_response" "success" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_rest_api.api.root_resource_id
  http_method       = aws_api_gateway_method.api.http_method
  status_code       = aws_api_gateway_method_response.success.status_code
  selection_pattern = "^2[0-9][0-9]" // regex pattern for any 200 message that comes back from SQS

  response_templates = {
    "application/json" = "{\"message\": \"great success!\"}"
  }

  depends_on = [aws_api_gateway_integration.api]
}

resource "aws_api_gateway_method_response" "success" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.api.http_method
  status_code = 200

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_deployment" "api" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = var.api_gateway_stage_name

  depends_on = [
    aws_api_gateway_integration.api,
  ]
}

output "test_cURL" {
  value = "curl -X POST -H 'Content-Type: application/json' -d '{\"id\":\"test\", \"docs\":[{\"key\":\"value\"}]}' ${aws_api_gateway_deployment.api.invoke_url}/"
}

# output "created_resources" {
#   value = {
#     "sqs_queue_arn"   = aws_sqs_queue.queue.arn,
#     "iam_role_arn"    = aws_iam_role.api.arn,
#     "api_gateway_arn" = aws_api_gateway_rest_api.api.arn,
#     # "request_validator_arn"   = aws_api_gateway_request_validator.api.id,
#     "integration_uri" = aws_api_gateway_integration.api.uri,
#   }
# }
