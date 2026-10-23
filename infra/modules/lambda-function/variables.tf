variable "name" {
  description = "Function name, also used for its IAM role and log group."
  type        = string
}

variable "source_dir" {
  description = "Local directory zipped as the deployment package."
  type        = string
}

variable "package_path" {
  description = "Where to write the zip. Defaults to .build/<name>.zip in the root module."
  type        = string
  default     = null
}

variable "handler" {
  description = "Function handler, e.g. \"handler.lambda_handler\"."
  type        = string
}

variable "runtime" {
  description = "Lambda runtime."
  type        = string
  default     = "python3.13"
}

variable "architectures" {
  description = "Instruction set; arm64 (Graviton) is cheaper."
  type        = list(string)
  default     = ["arm64"]
}

variable "memory_size" {
  description = "Memory in MB."
  type        = number
  default     = 128
}

variable "timeout" {
  description = "Timeout in seconds."
  type        = number
  default     = 10
}

variable "environment" {
  description = "Environment variables."
  type        = map(string)
  default     = {}
}

variable "reserved_concurrency" {
  description = "Reserved concurrency; -1 leaves it unreserved."
  type        = number
  default     = -1
}

variable "log_retention_days" {
  description = "CloudWatch log retention."
  type        = number
  default     = 30
}

variable "policy_name" {
  description = "Name of the inline policy on the function role."
  type        = string
  default     = "permissions"
}

variable "policy_statements" {
  description = "Extra IAM statements for the function role. Log permissions are added automatically."
  type        = any
  default     = []
}

variable "function_url" {
  description = "Creates a function URL when set. Use AWS_IAM auth behind CloudFront OAC."
  type = object({
    auth_type = optional(string, "AWS_IAM")
    cors = optional(object({
      allow_origins = list(string)
      allow_methods = list(string)
      allow_headers = optional(list(string), [])
      max_age       = optional(number, 0)
    }))
  })
  default = null
}

variable "circuit_breaker" {
  description = "Lets the function set its own concurrency to 0 under a flood; a schedule restores reserved_concurrency. Name is used for the schedule and its role."
  type = object({
    name     = string
    schedule = optional(string, "rate(1 hour)")
  })
  default = null
}
