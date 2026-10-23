# lambda-function

Lambda from a local source folder, with its role, log group (with retention), optional function URL,
and an optional circuit breaker: the function may set its own concurrency to 0 under a flood, and a
schedule restores `reserved_concurrency`.

```hcl
module "api" {
  source               = "../modules/lambda-function"
  name                 = "myapp-prod-api-ap-south-1"
  source_dir           = "${path.module}/src"
  handler              = "handler.lambda_handler"
  reserved_concurrency = 5
  policy_statements    = [{ Effect = "Allow", Action = "dynamodb:GetItem", Resource = module.table.arn }]
  function_url         = { cors = { allow_origins = ["https://example.com"], allow_methods = ["POST"] } }
  circuit_breaker      = { name = "myapp-prod-api-reset-ap-south-1" }
}
```
