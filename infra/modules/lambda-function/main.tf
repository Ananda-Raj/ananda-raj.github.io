data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

locals {
  package_path = coalesce(var.package_path, "${path.root}/.build/${var.name}.zip")
  function_arn = "arn:aws:lambda:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:function:${var.name}"

  statements = concat(
    [{
      Sid      = "Logs"
      Effect   = "Allow"
      Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
      Resource = "${aws_cloudwatch_log_group.this.arn}:*"
    }],
    var.policy_statements,
    [for s in [{
      Sid      = "Breaker"
      Effect   = "Allow"
      Action   = "lambda:PutFunctionConcurrency"
      Resource = local.function_arn
    }] : s if var.circuit_breaker != null],
  )
}

data "archive_file" "this" {
  type        = "zip"
  source_dir  = var.source_dir
  output_path = local.package_path
  excludes    = ["__pycache__"]
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = var.log_retention_days
}

resource "aws_iam_role" "this" {
  name = var.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "this" {
  name   = var.policy_name
  role   = aws_iam_role.this.id
  policy = jsonencode({ Version = "2012-10-17", Statement = local.statements })
}

resource "aws_lambda_function" "this" {
  function_name                  = var.name
  role                           = aws_iam_role.this.arn
  runtime                        = var.runtime
  architectures                  = var.architectures
  handler                        = var.handler
  filename                       = data.archive_file.this.output_path
  source_code_hash               = data.archive_file.this.output_base64sha256
  memory_size                    = var.memory_size
  timeout                        = var.timeout
  reserved_concurrent_executions = var.reserved_concurrency

  logging_config {
    log_format = "Text"
    log_group  = aws_cloudwatch_log_group.this.name
  }

  environment {
    variables = var.environment
  }

  depends_on = [aws_iam_role_policy.this]
}

resource "aws_lambda_function_url" "this" {
  count              = var.function_url == null ? 0 : 1
  function_name      = aws_lambda_function.this.function_name
  authorization_type = var.function_url.auth_type

  dynamic "cors" {
    for_each = var.function_url.cors == null ? [] : [var.function_url.cors]
    content {
      allow_origins = cors.value.allow_origins
      allow_methods = cors.value.allow_methods
      allow_headers = cors.value.allow_headers
      max_age       = cors.value.max_age
    }
  }
}

# Circuit breaker reset: puts reserved concurrency back on a schedule.
resource "aws_iam_role" "reset" {
  count = var.circuit_breaker == null ? 0 : 1
  name  = var.circuit_breaker.name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "scheduler.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = { StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id } }
    }]
  })
}

resource "aws_iam_role_policy" "reset" {
  count = var.circuit_breaker == null ? 0 : 1
  name  = "reset"
  role  = aws_iam_role.reset[0].id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:PutFunctionConcurrency"
      Resource = aws_lambda_function.this.arn
    }]
  })
}

resource "aws_scheduler_schedule" "reset" {
  count               = var.circuit_breaker == null ? 0 : 1
  name                = var.circuit_breaker.name
  schedule_expression = var.circuit_breaker.schedule

  flexible_time_window {
    mode = "OFF"
  }

  target {
    arn      = "arn:aws:scheduler:::aws-sdk:lambda:putFunctionConcurrency"
    role_arn = aws_iam_role.reset[0].arn
    input = jsonencode({
      FunctionName                 = aws_lambda_function.this.function_name
      ReservedConcurrentExecutions = var.reserved_concurrency
    })
  }

  lifecycle {
    precondition {
      condition     = var.reserved_concurrency > 0
      error_message = "circuit_breaker needs reserved_concurrency above 0."
    }
  }
}
