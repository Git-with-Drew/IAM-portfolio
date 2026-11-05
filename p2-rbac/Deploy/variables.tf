
variable "name_prefix" {
  description = "Unique lowercase prefix for S3 bucket names"
  type        = string

  validation {
    condition = (
      length(var.name_prefix) >= 3 &&
      length(var.name_prefix) <= 30 &&
      can(regex("^[a-z0-9][a-z0-9-]*[a-z0-9]$", var.name_prefix))
    )

    error_message = "Use 3-30 lowercase letters, numbers, or hyphens; start and end with a letter or number."
  }
}
