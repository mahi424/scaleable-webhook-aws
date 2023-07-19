provider "aws" {
  region = var.region
}

resource "aws_sqs_queue" "queue" {
  name                      = var.sqs_queue_name
  delay_seconds             = 0
  max_message_size          = 262144
  message_retention_seconds = 86400
  receive_wait_time_seconds = 10
}

resource "aws_iam_role" "api" {
  name = var.iam_role_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
        Effect = "Allow"
      },
    ]
  })
}

resource "aws_iam_policy" "api" {
  name = var.iam_policy_name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = [
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
  type                    = "AWS"
  integration_http_method = "POST"
  passthrough_behavior    = "NEVER"
  credentials             = aws_iam_role.api.arn
  uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.queue.name}"

  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
}

resource "aws_api_gateway_integration_response" "success" {
  rest_api_id       = aws_api_gateway_rest_api.api.id
  resource_id       = aws_api_gateway_rest_api.api.root_resource_id
  http_method       = aws_api_gateway_method.api.http_method
  status_code       = 200
  selection_pattern = "^2[0-9][0-9]"

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

output "created_resources" {
  value = {
    "sqs_queue_arn"   = aws_sqs_queue.queue.arn,
    "iam_role_arn"    = aws_iam_role.api.arn,
    "api_gateway_arn" = aws_api_gateway_rest_api.api.arn,
    "integration_uri" = aws_api_gateway_integration.api.uri,
  }
}
