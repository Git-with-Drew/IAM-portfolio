output "bucket_name" {
  value = aws_s3_bucket.data.id
}

output "bucket_arn" {
  value = aws_s3_bucket.data.arn
}

output "app_role_arn" {
  value = aws_iam_role.app.arn
}

output "boundary_demo_role_arn" {
  value = aws_iam_role.boundary_demo.arn
}

output "dev1_user_arn" {
  value = aws_iam_user.dev1.arn
}

# Contains the AWS account ID: do not paste these URLs or ARNs into public documents.
output "console_sign_in_url" {
  value = "https://${local.account_id}.signin.aws.amazon.com/console"
}

output "switch_role_url_app" {
  value = "https://signin.aws.amazon.com/switchrole?roleName=${aws_iam_role.app.name}&account=${local.account_id}&displayName=${aws_iam_role.app.name}"
}

output "switch_role_url_boundary_demo" {
  value = "https://signin.aws.amazon.com/switchrole?roleName=${aws_iam_role.boundary_demo.name}&account=${local.account_id}&displayName=${aws_iam_role.boundary_demo.name}"
}

output "s3_reports_console_url" {
  value = "https://s3.console.aws.amazon.com/s3/buckets/${aws_s3_bucket.data.id}?region=${var.region}&prefix=reports/"
}

# Retrieve with: terraform output -raw dev1_initial_password
output "dev1_initial_password" {
  value     = aws_iam_user_login_profile.dev1.password
  sensitive = true
}
