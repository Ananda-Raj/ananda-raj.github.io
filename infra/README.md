# Site API

The site is static (GitHub Pages), so anything that needs code or credentials runs here on AWS:

- **Live:** the contact form. Browser → CloudFront → Lambda → SES → email.
- **Phase 3, pending:** the AI assistant. Same path, with Lambda calling a model (see below).

Region `ap-south-1`. CloudFront is the only way in: it signs every request to the Lambda function URL,
filters traffic with AWS WAF, and sits on the free flat-rate plan (no overage charges). DynamoDB keeps
the rate-limit counters and the monthly AI spend.

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

Then, once:

1. Click the verification link SES emails to `notify_email`.
2. In the CloudFront console, subscribe the distribution to the **Free** flat-rate plan. It adds a web ACL
   with the core protections (common rule set, known bad inputs, Amazon IP reputation list).
   The common rule set blocks request bodies over 8 KB (`SizeRestrictions_BODY`), which cuts off long
   messages; in the WAF console, edit that rule group in the web ACL and set `SizeRestrictions_BODY` to
   **Count**. The Lambda already rejects bodies over 20 KB.
3. Add rate limiting: on the distribution's **Security** tab, edit **Security – Web Application Firewall
   (WAF)**, tick **Rate limiting** (30 requests per IP per 5 minutes), save, then choose **Monitor mode →
   Enable blocking**. It only counts requests until blocking is on. If the option isn't there, add a
   rate-based rule to the same web ACL in the WAF console (limit 30, 5-minute window, action Block).
   The free plan allows 5 rules.
4. Put the `api_url` output into the site settings (admin → Site settings → API URL).

Terraform ignores the web ACL on the distribution, as the provider can't manage pricing plans yet.

## Phase 3: AI assistant

Everything is deployed already; the chat is hidden by the **Show the AI chat** switch (admin → Site
settings), and the terminal's `ask` command and the "How this site works" page follow the same switch.

**Status:** Bedrock declined model access for this account (new accounts with little history; AWS says it
can change on its own over time). Both quotas below are 0.

**Check access:**

```
aws service-quotas get-service-quota --region ap-south-1 --service-code bedrock --quota-code L-9A11C666   # tokens/min
aws service-quotas get-service-quota --region ap-south-1 --service-code bedrock --quota-code L-E5084BBA   # requests/min
```

**Option A, wait for Bedrock (recommended):** once both quotas are above 0,

1. Send one message to the model in the Bedrock playground. This completes model access for the
   account; the Lambda role can't do it, by design.
2. Turn on **Show the AI chat**. The site rebuilds and the chat appears.
3. Ask it a few questions and watch the Lambda's CloudWatch logs.

**Option B, same model through the vendor's own API:** if Bedrock stays closed,

1. Create an API account with the model vendor and add a small prepaid credit.
2. Store the key in SSM Parameter Store as a SecureString (never in the repo).
3. Add a provider switch to the Lambda (`MODEL_PROVIDER = bedrock | api`), read the key from SSM, and
   allow the role `ssm:GetParameter` on that one parameter.
4. Turn on **Show the AI chat**. Switching back to Bedrock later is one variable.

Limits apply either way: 10 questions per visitor per hour, 30 per day, 150 per day for the site, and a
monthly model budget of $1 (`monthly_ai_budget_usd`), after which the chat rests until the 1st.

## Tests

```
cd infra/api && python3 -m unittest discover tests
```
