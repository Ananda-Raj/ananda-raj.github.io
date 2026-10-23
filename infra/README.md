# Site API

Backend for the AI assistant and the contact form: CloudFront → Lambda (Python, arm64) → Amazon Bedrock,
with DynamoDB for limits and SES for email. Region `ap-south-1`.

## Layout

- `state-bucket.sh` creates the S3 bucket that holds Terraform state for every stack (once per account)
- `modules/` reusable building blocks:
  - `dynamodb-table`: single-key table with optional TTL
  - `lambda-function`: function, role, logs, optional function URL and circuit breaker
  - `cloudfront-lambda-url`: CloudFront with origin access control in front of a function URL
  - `bedrock-invoke-policy`: IAM statements for a cross-Region inference profile
- `api/` the site API built from the modules; Lambda code in `api/src`, tests in `api/tests`

All settings are defaults in `variables.tf`, and state lives in the S3 bucket. Credentials come from the
shell (`AWS_PROFILE`); with the wrong profile Terraform can't read the state bucket and stops.

## Deploy

```
export AWS_PROFILE=<your profile>
./infra/state-bucket.sh          # first time only
cd infra/api
terraform init
terraform apply
```

Then:

1. Click the verification link SES emails to `notify_email`.
2. In the CloudFront console, subscribe the distribution to the free flat-rate plan and add an IP rate-limit rule.
3. Invoke the model once in the Bedrock playground (sets up model access).
4. Put the `api_url` output into the site settings (admin → Site settings → API URL).

## Tests

```
cd infra/api && python3 -m unittest discover tests
```
