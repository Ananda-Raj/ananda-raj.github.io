# dynamodb-table

Single-key DynamoDB table with optional TTL. Defaults to 5/5 provisioned capacity, which stays in the free tier.

```hcl
module "table" {
  source        = "../modules/dynamodb-table"
  name          = "myapp-prod-limits-ap-south-1"
  hash_key      = "pk"
  ttl_attribute = "expires"
}
```
