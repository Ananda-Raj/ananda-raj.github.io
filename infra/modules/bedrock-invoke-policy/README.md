# bedrock-invoke-policy

No resources: returns the IAM statements needed to call a Bedrock model through a cross-Region
inference profile. Global profiles (`global.` prefix) get the three-part policy AWS documents;
geographic profiles (`us.`, `eu.`, `apac.` …) get access to the model in any Region of that profile.

```hcl
module "bedrock" {
  source               = "../modules/bedrock-invoke-policy"
  region               = "ap-south-1"
  account_id           = data.aws_caller_identity.current.account_id
  inference_profile_id = "global.<model-id>"
  foundation_model_id  = "<model-id>"
}

# policy_statements = module.bedrock.statements
```
