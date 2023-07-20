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


output "test_cURL" {
  value = "curl -X POST -H 'Content-Type: application/json' -d '{\"id\":\"test\", \"docs\":[{\"key\":\"value\"}]}' ${aws_api_gateway_deployment.api.invoke_url}/"
}

resource "aws_sqs_queue" "queue" {
  name                      = var.sqs_queue_name
  delay_seconds             = 0      // how long to delay delivery of records
  max_message_size          = 262144 // = 256KiB, which is the limit set by AWS
  message_retention_seconds = 86400  // = 1 day in seconds
  receive_wait_time_seconds = 10     // how long to wait for a record to stream in when ReceiveMessage is called
}


data "archive_file" "forward_to_sqs_lambda" {
  type        = "zip"
  source_file = "./forward_to_sqs_lambda.zip"
  output_path = "forward_to_sqs_lambda.zip"
}
resource "aws_lambda_function" "forward_to_sqs" {
  function_name    = "forward_to_sqs_lambda"
  role             = aws_iam_role.lambda.arn
  handler          = "index.handler"
  runtime          = "nodejs14.x"
  filename         = "forward_to_sqs_lambda.zip"
  source_code_hash = filebase64sha256("forward_to_sqs_lambda.zip")

  environment {
    variables = {
      QueueUrl = aws_sqs_queue.queue.id
    }
  }
}

resource "aws_iam_role" "lambda" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action    = "sts:AssumeRole"
        Effect    = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "lambda" {
  name = "lambda-policy"

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
        Effect = "Allow",
        "Sid" : ""
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

# resource "aws_api_gateway_request_validator" "api" {
#   rest_api_id           = "${aws_api_gateway_rest_api.api.id}"
#   name                  = "payload-validator"
#   validate_request_body = true
# }

# resource "aws_api_gateway_model" "api" {
#   rest_api_id  = "${aws_api_gateway_rest_api.api.id}"
#   name         = "PayloadValidator"
#   description  = "validate the json body content conforms to the below spec"
#   content_type = "application/json"

#   schema = <<EOF
# {
#   "$schema": "http://json-schema.org/draft-04/schema#",
#   "type": "object",
#   "required": [ "id", "docs"],
#   "properties": {
#     "id": { "type": "string" },
#     "docs": {
#       "minItems": 1,
#       "type": "array",
#       "items": {
#         "type": "object"
#       }
#     }
#   }
# }
# EOF
# }

resource "aws_api_gateway_method" "api" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_rest_api.api.root_resource_id
  api_key_required = false
  http_method      = "POST"
  authorization    = "NONE"
  #   request_validator_id = "${aws_api_gateway_request_validator.api.id}"

  #   request_models = {
  #     "application/json" = "${aws_api_gateway_model.api.name}"
  #   }
}

# resource "aws_api_gateway_integration" "api" {
#   rest_api_id             = aws_api_gateway_rest_api.api.id
#   resource_id             = aws_api_gateway_rest_api.api.root_resource_id
#   http_method             = "POST"
#   type                    = "AWS"
#   integration_http_method = "POST"
#   passthrough_behavior    = "NEVER"
#   credentials             = aws_iam_role.api.arn
#   uri                     = "arn:aws:apigateway:${var.region}:sqs:path/${aws_sqs_queue.queue.name}"

#   request_parameters = {
#     "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
#   }

#   request_templates = {
#     "application/json" = "Action=SendMessage&MessageBody=$input.body"
#   }
# }

resource "aws_api_gateway_integration" "api" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_rest_api.api.root_resource_id
  http_method             = "POST"
  type                    = "AWS_PROXY"  # Use AWS_PROXY for Lambda integration
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

output "created_resources" {
  value = {
    "sqs_queue_arn"   = aws_sqs_queue.queue.arn,
    "iam_role_arn"    = aws_iam_role.api.arn,
    "api_gateway_arn" = aws_api_gateway_rest_api.api.arn,
    # "request_validator_arn"   = aws_api_gateway_request_validator.api.id,
    "integration_uri" = aws_api_gateway_integration.api.uri,
  }
}
