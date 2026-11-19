data "aws_iam_policy_document" "policy" {
  statement {
    sid = "ListBucket"
    
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      "arn:aws:s3:::BUCKET"
    ]
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
}
