variable "bucket_name" {
  description = "State bucket name, e.g. \"myapp-prod-tfstate-123456789012\"."
  type        = string
}

variable "noncurrent_version_days" {
  description = "Days to keep old state versions."
  type        = number
  default     = 90
}
