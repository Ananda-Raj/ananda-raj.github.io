# cloudfront-lambda-url

CloudFront distribution for a Lambda function URL, with origin access control and both Lambda
permissions CloudFront needs. Caching is off and all viewer headers except Host are forwarded.
Browsers sending POST or PUT must include `x-amz-content-sha256` (hex SHA-256 of the body).

```hcl
module "cdn" {
  source        = "../modules/cloudfront-lambda-url"
  name          = "myapp-prod-api"
  function_name = module.api.function_name
  function_url  = module.api.function_url
}
```
