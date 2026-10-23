variable "name" {
  description = "Name for the origin access control; also the default distribution comment."
  type        = string
}

variable "comment" {
  description = "Distribution comment."
  type        = string
  default     = null
}

variable "function_name" {
  description = "Lambda function behind the URL."
  type        = string
}

variable "function_url" {
  description = "Lambda function URL (AWS_IAM auth)."
  type        = string
}

variable "price_class" {
  description = "PriceClass_100, PriceClass_200 or PriceClass_All."
  type        = string
  default     = "PriceClass_200"
}
