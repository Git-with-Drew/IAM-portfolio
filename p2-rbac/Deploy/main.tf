
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
  region = "us-east-1"
}

locals {
  groups = toset([
    "aws-sales-rep",
    "aws-hr-specialist",
    "aws-finance-analyst",
    "aws-it-helpdesk",
    "aws-it-admin",
  ])

  users = {
    sales1    = "aws-sales-rep"
    hr1       = "aws-hr-specialist"
    fin1      = "aws-finance-analyst"
    helpdesk1 = "aws-it-helpdesk"
    itadmin1  = "aws-it-admin"
  }

  buckets = toset([
    "${var.name_prefix}-iam-lab-sales-data",
    "${var.name_prefix}-iam-lab-hr-data",
    "${var.name_prefix}-iam-lab-finance-data",
  ])
}

# S3 buckets
resource "aws_s3_bucket" "lab" {
  for_each = local.buckets

  bucket = each.value
}

# Keep all four public access protections enabled.
resource "aws_s3_bucket_public_access_block" "lab" {
  for_each = aws_s3_bucket.lab

  bucket = each.value.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Upload the same dummy file to each bucket.
resource "aws_s3_object" "test_file" {
  for_each = aws_s3_bucket.lab

  bucket       = each.value.id
  key          = "test.txt"
  source       = "${path.module}/test.txt"
  content_type = "text/plain"

  depends_on = [
    aws_s3_bucket_public_access_block.lab
  ]
}

# IAM groups: intentionally no policies attached.
resource "aws_iam_group" "lab" {
  for_each = local.groups

  name = each.value
}

# IAM users
resource "aws_iam_user" "lab" {
  for_each = local.users

  name = each.key
}

# Enable console access and require password replacement
# at the first sign-in.
resource "aws_iam_user_login_profile" "lab" {
  for_each = local.users

  user                    = aws_iam_user.lab[each.key].name
  password_length         = 20
  password_reset_required = true
}

# Add each user to the designated group.
resource "aws_iam_user_group_membership" "lab" {
  for_each = local.users

  user = aws_iam_user.lab[each.key].name

  groups = [
    aws_iam_group.lab[each.value].name
  ]
}


# ------------------------------------------------
# IAM POLICY DOCUMENTS
# ------------------------------------------------

locals {
  policy_documents = {

    # 1. Console navigation: list all S3 buckets
    pol-console-nav = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Sid      = "ListBuckets"
        Effect   = "Allow"
        Action   = "s3:ListAllMyBuckets"
        Resource = "*"
      }]
    })

    # 2. Sales read/write
    pol-sales-data-rw = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListBucket"
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-sales-data"
        },
        {
          Sid    = "ReadWriteObjects"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-sales-data/*"
        }
      ]
    })

    # 3. Sales read-only
    pol-sales-data-ro = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListBucket"
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-sales-data"
        },
        {
          Sid      = "ReadObjects"
          Effect   = "Allow"
          Action   = "s3:GetObject"
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-sales-data/*"
        }
      ]
    })

    # 4. HR read/write
    pol-hr-data-rw = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListBucket"
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-hr-data"
        },
        {
          Sid    = "ReadWriteObjects"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-hr-data/*"
        }
      ]
    })

    # 5. Finance read/write
    pol-finance-data-rw = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Sid      = "ListBucket"
          Effect   = "Allow"
          Action   = "s3:ListBucket"
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-finance-data"
        },
        {
          Sid    = "ReadWriteObjects"
          Effect = "Allow"
          Action = [
            "s3:GetObject",
            "s3:PutObject"
          ]
          Resource = "arn:aws:s3:::${var.name_prefix}-iam-lab-finance-data/*"
        }
      ]
    })

    # 6. EC2 read-only
    pol-ec2-readonly = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect   = "Allow"
        Action   = "ec2:Describe*"
        Resource = "*"
      }]
    })

    # 7. S3 bucket configuration read
    pol-s3-config-read = jsonencode({
      Version = "2012-10-17"
      Statement = [{
        Effect = "Allow"
        Action = [
          "s3:GetBucketPolicy",
          "s3:GetBucketTagging",
          "s3:GetBucketLocation"
        ]
        Resource = [
          "arn:aws:s3:::${var.name_prefix}-iam-lab-sales-data",
          "arn:aws:s3:::${var.name_prefix}-iam-lab-hr-data",
          "arn:aws:s3:::${var.name_prefix}-iam-lab-finance-data"
        ]
      }]
    })
  }
}

# ------------------------------------------------
# CREATE IAM CUSTOMER-MANAGED POLICIES
# ------------------------------------------------

resource "aws_iam_policy" "lab" {
  for_each = local.policy_documents

  name        = each.key
  description = "Terraform-managed policy: ${each.key}"
  policy      = each.value
}


# ------------------------------------------------
# ATTACH CONSOLE NAVIGATION TO ALL GROUPS
# ------------------------------------------------

resource "aws_iam_group_policy_attachment" "console_nav" {
  for_each = local.groups

  group      = aws_iam_group.lab[each.key].name
  policy_arn = aws_iam_policy.lab["pol-console-nav"].arn
}

# ------------------------------------------------
# GROUP-TO-POLICY ATTACHMENT MATRIX
# ------------------------------------------------

locals {
  group_policy_assignments = {
    aws-sales-rep = [
      "pol-sales-data-rw"
    ]

    aws-hr-specialist = [
      "pol-hr-data-rw"
    ]

    aws-finance-analyst = [
      "pol-sales-data-ro",
      "pol-finance-data-rw"
    ]

    aws-it-helpdesk = [
      "pol-ec2-readonly"
    ]

    aws-it-admin = [
      "pol-ec2-readonly",
      "pol-s3-config-read"
    ]
  }

  group_policy_pairs = {
    for assignment in flatten([
      for group, policies in local.group_policy_assignments : [
        for policy in policies : {
          group  = group
          policy = policy
        }
      ]
    ]) :
    "${assignment.group}-${assignment.policy}" => assignment
  }
}

# Attach role-specific policies to IAM groups.
resource "aws_iam_group_policy_attachment" "role_policies" {
  for_each = local.group_policy_pairs

  group = aws_iam_group.lab[each.value.group].name

  policy_arn = aws_iam_policy.lab[each.value.policy].arn
}

