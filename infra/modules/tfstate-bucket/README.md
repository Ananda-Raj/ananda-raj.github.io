# tfstate-bucket

S3 bucket for Terraform state: versioned, encrypted, private, HTTPS only, old versions expire.
Use with `use_lockfile = true` in the backend (Terraform >= 1.10); no DynamoDB lock table needed.

```hcl
module "state_bucket" {
  source      = "../modules/tfstate-bucket"
  bucket_name = "myapp-prod-tfstate-123456789012"
}
```
