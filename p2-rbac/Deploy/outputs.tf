
output "s3_bucket_names" {
  description = "Created S3 bucket names"
  value       = sort(keys(aws_s3_bucket.lab))
}

output "iam_groups" {
  description = "Created IAM groups"
  value       = sort(keys(aws_iam_group.lab))
}

output "iam_users_and_groups" {
  description = "IAM user-to-group assignments"
  value       = local.users
}

output "initial_console_passwords" {
  description = "Initial IAM console passwords, which are required to be changed at first sign-in."
  value = {
    for username, profile in aws_iam_user_login_profile.lab :
    username => profile.password
  }
  sensitive = true
}
