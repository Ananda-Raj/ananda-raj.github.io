# IAM statements for bedrock:InvokeModel through a cross-Region inference profile.
# Global profiles need the Region-less model ARN as well.
locals {
  profile_arn = "arn:aws:bedrock:${var.region}:${var.account_id}:inference-profile/${var.inference_profile_id}"
  is_global   = startswith(var.inference_profile_id, "global.")

  profile = [{
    Sid       = "ModelProfile"
    Effect    = "Allow"
    Action    = "bedrock:InvokeModel"
    Resource  = local.profile_arn
    Condition = { StringEquals = { "aws:RequestedRegion" = var.region } }
  }]

  global = [
    {
      Sid      = "ModelInRegion"
      Effect   = "Allow"
      Action   = "bedrock:InvokeModel"
      Resource = "arn:aws:bedrock:${var.region}::foundation-model/${var.foundation_model_id}"
      Condition = { StringEquals = {
        "aws:RequestedRegion"         = var.region
        "bedrock:InferenceProfileArn" = local.profile_arn
      } }
    },
    {
      Sid      = "ModelGlobal"
      Effect   = "Allow"
      Action   = "bedrock:InvokeModel"
      Resource = "arn:aws:bedrock:::foundation-model/${var.foundation_model_id}"
      Condition = { StringEquals = {
        "aws:RequestedRegion"         = "unspecified"
        "bedrock:InferenceProfileArn" = local.profile_arn
      } }
    },
  ]

  geographic = [{
    Sid       = "ModelInGeography"
    Effect    = "Allow"
    Action    = "bedrock:InvokeModel"
    Resource  = "arn:aws:bedrock:*::foundation-model/${var.foundation_model_id}"
    Condition = { StringEquals = { "bedrock:InferenceProfileArn" = local.profile_arn } }
  }]
}
