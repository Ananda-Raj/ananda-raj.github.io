variable "aws_region" {
  type    = string
  default = "ap-south-1"
}

variable "aws_profile" {
  type = string
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

variable "noncurrent_state_days" {
  type    = number
  default = 90
}
