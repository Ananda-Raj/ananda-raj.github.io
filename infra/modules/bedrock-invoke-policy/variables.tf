variable "region" {
  description = "Region the calls are made from."
  type        = string
}

variable "account_id" {
  description = "Account that owns the inference profile."
  type        = string
}

variable "inference_profile_id" {
  description = "Inference profile ID, e.g. \"global.<model-id>\" or \"apac.<model-id>\"."
  type        = string
}

variable "foundation_model_id" {
  description = "Model behind the profile."
  type        = string
}
