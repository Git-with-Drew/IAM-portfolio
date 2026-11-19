
data "aws_iam_policy_document" "policy" {
  statement {
    sid = "ListReportsPrefix"
    
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::BUCKET"
    ]
    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values   = [
        "reports/*"
      ]
    }
    
  }
  statement {
    sid = "ReadReports"
    
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "arn:aws:s3:::BUCKET/reports/*"
    ]
  }
  statement {
    sid = "WriteLogs"
    
    actions = [
      "s3:PutObject"
    ]
    resources = [
      "arn:aws:s3:::BUCKET/logs/*"
    ]
  }
  statement {
    sid = "DenyInsecureTransport"
    
    effect = "Deny"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::BUCKET",
      "arn:aws:s3:::BUCKET/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = [
        "false"
      ]
    }
    
  }
}