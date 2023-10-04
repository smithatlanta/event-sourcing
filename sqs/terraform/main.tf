# Lambda Function
resource "aws_lambda_function" "lambda" {
  filename      = "lambda.zip"
  function_name = "lambda"
  role          = aws_iam_role.iam_lambda_sqs.arn
  handler       = "lambda"
  runtime       = "go1.x"
  timeout       = 15
}

# IAM Role for Lambda Function
resource "aws_iam_role" "lambda_iam" {
  name               = "lambda_iam_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

# Assume Role Policy
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

# Policies allowed while Lambda is running
resource "aws_iam_role_policy" "lambda_role_policy" {
  name   = "lambda_iam_role_policy"
  role   = aws_iam_role.iam_lambda_sqs.id
  policy = data.aws_iam_policy_document.lambda_sqs_policy.json
}

data "aws_iam_policy_document" "lambda_policy" {
  # use of sqs buckets
  statement {
    actions = [
      "sqs:*",
    ]
    resources = [aws_sqs_queue.lambda_sqs.arn]
  }

  statement {
    actions = [
      "cloudwatch:*"
    ]
    resources = ["*"]
  }

  statement {
    actions = [
      "logs:*"
    ]
    resources = ["*"]
  }
}

# SQS Queue
resource "aws_sqs_queue" "lambda_sqs" {
  name                      = "lambda-sqs"
  delay_seconds             = 0
  max_message_size          = 262144 # max
  message_retention_seconds = 86400  # 24 hours

  # To allow your function time to process each batch of records, set the source queue's visibility timeout 
  # to at least 6 times the timeout that you configure on your function. The extra time allows for Lambda 
  # to retry if your function execution is throttled while your function is processing a previous batch. 
  visibility_timeout_seconds = 60

  receive_wait_time_seconds = 0
  redrive_policy = jsonencode({
    deadLetterTargetArn = aws_sqs_queue.lambda_sqs_dlq.arn
    maxReceiveCount     = 4
  })
}

# SQS Dead Letter Queue
resource "aws_sqs_queue" "lambda_sqs_dlq" {
  name                      = "lambda-sqs-dlq"
  delay_seconds             = 0
  max_message_size          = 262144 # max
  message_retention_seconds = 604800 # 7 days

  # To allow your function time to process each batch of records, set the source queue's visibility timeout 
  # to at least 6 times the timeout that you configure on your function. The extra time allows for Lambda 
  # to retry if your function execution is throttled while your function is processing a previous batch. 
  visibility_timeout_seconds = 60

  receive_wait_time_seconds = 0
}

# Event Source Mapping
resource "aws_lambda_event_source_mapping" "mapping_moderation" {
  event_source_arn = aws_sqs_queue.moderation.arn
  function_name    = aws_lambda_function.lambda_moderation.arn
}