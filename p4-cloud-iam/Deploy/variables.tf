variable "name_prefix" {
  description = "Short, unique, lowercase prefix for the bucket name (<prefix>-p4-data). Avoid personal info; it appears in the bucket name."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.name_prefix))
    error_message = "name_prefix must be 3-20 characters: lowercase letters, digits, and hyphens, starting and ending with a letter or digit."
  }
}

variable "region" {
  description = "AWS region for the lab."
  type        = string
  default     = "us-east-1"
}
