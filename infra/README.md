# Site API

Backend for the AI assistant and the contact form: CloudFront → Lambda (Python, arm64) → Amazon Bedrock,
with DynamoDB for limits and SES for email. Region `ap-south-1`.

## Layout

- `modules/` reusable building blocks:
  - `tfstate-bucket`: S3 state bucket (versioned, encrypted, HTTPS only)
  - `dynamodb-table`: single-key table with optional TTL
  - `lambda-function`: function, role, logs, optional function URL and circuit breaker
  - `cloudfront-lambda-url`: CloudFront with origin access control in front of a function URL
  - `bedrock-invoke-policy`: IAM statements for a cross-Region inference profile
- `bootstrap/` the state bucket (local state)
- `api/` the site API built from the modules; Lambda code in `api/src`, tests in `api/tests`

## First deploy

1. State bucket (once):
   ```
   cd infra/bootstrap
   cp terraform.tfvars.example terraform.tfvars   # set aws_profile
   terraform init && terraform apply
   ```
2. API:
   ```
   cd infra/api
   cp backend.hcl.example backend.hcl             # set bucket and profile
   cp terraform.tfvars.example terraform.tfvars   # set aws_profile and notify_email
   terraform init -backend-config=backend.hcl
   terraform apply
   ```
3. Click the verification link SES emails to `notify_email`.
4. In the CloudFront console, subscribe the distribution to the free flat-rate plan and add an IP rate-limit rule.
5. Invoke the model once in the Bedrock playground (sets up model access), then put the `api_url` output
   into the site settings (admin → Site settings → API URL).

## Tests

```
cd infra/api && python3 -m unittest discover tests
```
