# CloudFront in front of a Lambda function URL. OAC signs every request, so the URL
# only answers this distribution. POST/PUT callers must send x-amz-content-sha256.
data "aws_cloudfront_cache_policy" "disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_but_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.name
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  comment         = coalesce(var.comment, var.name)
  price_class     = var.price_class
  http_version    = "http2and3"
  is_ipv6_enabled = true

  origin {
    origin_id                = "lambda"
    domain_name              = split("/", var.function_url)[2]
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id         = "lambda"
    viewer_protocol_policy   = "https-only"
    allowed_methods          = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods           = ["GET", "HEAD"]
    cache_policy_id          = data.aws_cloudfront_cache_policy.disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_but_host.id
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  # A flat-rate pricing plan, chosen in the console, attaches its own WAF web ACL.
  lifecycle {
    ignore_changes = [web_acl_id]
  }
}

resource "aws_lambda_permission" "url" {
  statement_id           = "AllowCloudFrontInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = var.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.this.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_permission" "invoke" {
  statement_id             = "AllowCloudFrontInvokeFunction"
  action                   = "lambda:InvokeFunction"
  function_name            = var.function_name
  principal                = "cloudfront.amazonaws.com"
  source_arn               = aws_cloudfront_distribution.this.arn
  invoked_via_function_url = true
}
