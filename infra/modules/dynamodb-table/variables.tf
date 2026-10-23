variable "name" {
  description = "Table name."
  type        = string
}

variable "hash_key" {
  description = "Partition key attribute name."
  type        = string
}

variable "hash_key_type" {
  description = "Partition key type: S, N or B."
  type        = string
  default     = "S"
}

variable "ttl_attribute" {
  description = "Attribute holding an expiry epoch; null disables TTL."
  type        = string
  default     = null
}

variable "billing_mode" {
  description = "PROVISIONED (free-tier friendly, throttles under load) or PAY_PER_REQUEST."
  type        = string
  default     = "PROVISIONED"
}

variable "read_capacity" {
  description = "Read units when PROVISIONED."
  type        = number
  default     = 5
}

variable "write_capacity" {
  description = "Write units when PROVISIONED."
  type        = number
  default     = 5
}
