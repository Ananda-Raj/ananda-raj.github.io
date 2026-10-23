variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "project" {
  type    = string
  default = "ananda-raj-site"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "owner" {
  type    = string
  default = "Ananda Raj"
}

variable "site_url" {
  type    = string
  default = "https://ananda-raj.github.io"
}

variable "dev_origins" {
  description = "Local preview origins allowed to call the API."
  type        = list(string)
  default     = ["http://localhost:4321", "http://localhost:4322"]
}

variable "notify_email" {
  description = "Receives contact form messages. Must be verified in SES (AWS emails a link)."
  type        = string
  default     = "vanandaraj0001@gmail.com"
}

variable "model_id" {
  description = "Bedrock inference profile used by the assistant."
  type        = string
  default     = "global.anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "foundation_model" {
  description = "Foundation model behind model_id, for IAM."
  type        = string
  default     = "anthropic.claude-haiku-4-5-20251001-v1:0"
}

variable "price_input_per_mtok" {
  description = "USD per million input tokens, used for the monthly cap."
  type        = number
  default     = 1
}

variable "price_output_per_mtok" {
  description = "USD per million output tokens, used for the monthly cap."
  type        = number
  default     = 5
}

variable "monthly_ai_budget_usd" {
  description = "The assistant pauses until next month once this is spent."
  type        = number
  default     = 1
}

variable "reserved_concurrency" {
  description = "Upper bound on parallel requests."
  type        = number
  default     = 5
}

variable "log_retention_days" {
  type    = number
  default = 30
}
