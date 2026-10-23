data "aws_caller_identity" "current" {}

locals {
  name       = "${var.project}-${var.environment}"
  account_id = data.aws_caller_identity.current.account_id
  origins    = concat([var.site_url], var.dev_origins)
}

resource "random_id" "ip_salt" {
  byte_length = 16
}

resource "aws_sesv2_email_identity" "notify" {
  email_identity = var.notify_email
}

# Rate-limit counters and the monthly spend total.
module "limits_table" {
  source        = "../modules/dynamodb-table"
  name          = "${local.name}-limits-${var.aws_region}"
  hash_key      = "pk"
  ttl_attribute = "expires"
}

module "bedrock_policy" {
  source               = "../modules/bedrock-invoke-policy"
  region               = var.aws_region
  account_id           = local.account_id
  inference_profile_id = var.model_id
  foundation_model_id  = var.foundation_model
}

module "api" {
  source               = "../modules/lambda-function"
  name                 = "${local.name}-api-${var.aws_region}"
  source_dir           = "${path.module}/src"
  package_path         = "${path.module}/.build/api.zip"
  handler              = "handler.lambda_handler"
  memory_size          = 256
  timeout              = 25
  reserved_concurrency = var.reserved_concurrency
  log_retention_days   = var.log_retention_days
  policy_name          = "api"

  policy_statements = concat(
    [{
      Sid      = "Limits"
      Effect   = "Allow"
      Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
      Resource = module.limits_table.arn
    }],
    module.bedrock_policy.statements,
    [{
      Sid       = "Email"
      Effect    = "Allow"
      Action    = "ses:SendEmail"
      Resource  = aws_sesv2_email_identity.notify.arn
      Condition = { StringEquals = { "ses:FromAddress" = var.notify_email } }
    }],
  )

  environment = {
    TABLE_NAME            = module.limits_table.name
    MODEL_ID              = var.model_id
    CONTEXT_URL           = "${var.site_url}/ai/context.json"
    ALLOWED_ORIGINS       = join(",", local.origins)
    MAIL_TO               = var.notify_email
    MAIL_FROM             = var.notify_email
    IP_SALT               = random_id.ip_salt.hex
    MONTHLY_BUDGET_USD    = tostring(var.monthly_ai_budget_usd)
    PRICE_INPUT_PER_MTOK  = tostring(var.price_input_per_mtok)
    PRICE_OUTPUT_PER_MTOK = tostring(var.price_output_per_mtok)
  }

  function_url = {
    auth_type = "AWS_IAM"
    cors = {
      allow_origins = local.origins
      allow_methods = ["POST"]
      allow_headers = ["content-type", "x-amz-content-sha256"]
      max_age       = 3600
    }
  }

  circuit_breaker = {
    name = "${local.name}-api-reset-${var.aws_region}"
  }
}

module "cdn" {
  source        = "../modules/cloudfront-lambda-url"
  name          = "${local.name}-api"
  comment       = "${local.name} api"
  function_name = module.api.function_name
  function_url  = module.api.function_url
}
