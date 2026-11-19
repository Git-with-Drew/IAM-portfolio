# Project 4 lab scenario (fictional):
#   - Bucket <prefix>-p4-data with reports/, logs/, secret/ prefixes (one small file each)
#   - p4-app-role: read reports/*, write logs/*, nothing else
#   - dev1 (IAM user): may assume the lab roles only with MFA
#   - p4-boundary-demo: a deliberately broad role capped by a permission boundary

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project   = "p4-cloud-iam"
      ManagedBy = "terraform"
    }
  }
}

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name_prefix}-p4-data"
  account_id  = data.aws_caller_identity.current.account_id
}

# ---------------------------------------------------------------------------
# Data bucket and seed objects
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "data" {
  bucket = local.bucket_name

  # Tests write objects outside Terraform, so allow destroy to empty the bucket.
  force_destroy = true
}

resource "aws_s3_bucket_public_access_block" "data" {
  bucket                  = aws_s3_bucket.data.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "seed" {
  for_each = {
    "reports/q3.txt"  = "Fictional Q3 sales report."
    "logs/seed.txt"   = "Fictional application log line."
    "secret/hr.txt"   = "Fictional confidential HR note."
  }

  bucket  = aws_s3_bucket.data.id
  key     = each.key
  content = each.value

  depends_on = [aws_s3_bucket_public_access_block.data]
}

# ---------------------------------------------------------------------------
# Developer user and group
# ---------------------------------------------------------------------------

resource "aws_iam_user" "dev1" {
  name          = "dev1"
  force_destroy = true # also removes console login and MFA devices added outside Terraform
}

resource "aws_iam_user_login_profile" "dev1" {
  user                    = aws_iam_user.dev1.name
  password_length         = 20
  password_reset_required = true
}

resource "aws_iam_group" "developers" {
  name = "aws-p4-developers"
}

resource "aws_iam_group_membership" "developers" {
  name  = "p4-developers-membership"
  group = aws_iam_group.developers.name
  users = [aws_iam_user.dev1.name]
}

# dev1 can assume the two lab roles (only with MFA), change their own password,
# and read the account password policy. Nothing else.
data "aws_iam_policy_document" "dev1" {
  statement {
    sid       = "AssumeLabRolesWithMfa"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = [aws_iam_role.app.arn, aws_iam_role.boundary_demo.arn]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid       = "ChangeOwnPassword"
    effect    = "Allow"
    actions   = ["iam:ChangePassword"]
    resources = [aws_iam_user.dev1.arn]
  }

  statement {
    sid       = "ReadPasswordPolicy"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "dev1" {
  name   = "pol-p4-dev1-assume"
  policy = data.aws_iam_policy_document.dev1.json
}

resource "aws_iam_group_policy_attachment" "developers" {
  group      = aws_iam_group.developers.name
  policy_arn = aws_iam_policy.dev1.arn
}

# ---------------------------------------------------------------------------
# Trust policy shared by both roles: only dev1, only with MFA
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "trust_mfa" {
  statement {
    sid     = "AssumeWithMfa"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [aws_iam_user.dev1.arn]
    }

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }
}

# ---------------------------------------------------------------------------
# p4-app-role: least privilege (read reports/*, write logs/*)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "app_role" {
  statement {
    sid       = "ListReportsPrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = ["reports/*"]
    }
  }

  statement {
    sid       = "ReadReports"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data.arn}/reports/*"]
  }

  statement {
    sid       = "WriteLogs"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.data.arn}/logs/*"]
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.data.arn, "${aws_s3_bucket.data.arn}/*"]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_iam_policy" "app_role" {
  name   = "pol-p4-app-role"
  policy = data.aws_iam_policy_document.app_role.json
}

resource "aws_iam_role" "app" {
  name                 = "p4-app-role"
  assume_role_policy   = data.aws_iam_policy_document.trust_mfa.json
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "app" {
  role       = aws_iam_role.app.name
  policy_arn = aws_iam_policy.app_role.arn
}

# ---------------------------------------------------------------------------
# p4-boundary-demo: deliberately broad policy, capped by a permission boundary
# Effective permissions = intersection of the two.
# ---------------------------------------------------------------------------

# WARNING: intentionally over-permissive for the lab. The boundary below is what limits it.
data "aws_iam_policy_document" "broad_demo" {
  statement {
    sid       = "DeliberatelyBroad"
    effect    = "Allow"
    actions   = ["s3:*"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "broad_demo" {
  name   = "pol-p4-broad-demo"
  policy = data.aws_iam_policy_document.broad_demo.json
}

data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "ListBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.data.arn]
  }

  statement {
    sid       = "ReadReports"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.data.arn}/reports/*"]
  }

  statement {
    sid       = "WriteLogs"
    effect    = "Allow"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.data.arn}/logs/*"]
  }
}

resource "aws_iam_policy" "boundary" {
  name   = "pol-p4-boundary"
  policy = data.aws_iam_policy_document.boundary.json
}

resource "aws_iam_role" "boundary_demo" {
  name                 = "p4-boundary-demo"
  assume_role_policy   = data.aws_iam_policy_document.trust_mfa.json
  permissions_boundary = aws_iam_policy.boundary.arn
  max_session_duration = 3600
}

resource "aws_iam_role_policy_attachment" "boundary_demo" {
  role       = aws_iam_role.boundary_demo.name
  policy_arn = aws_iam_policy.broad_demo.arn
}
