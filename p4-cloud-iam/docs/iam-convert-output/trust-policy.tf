data "aws_iam_policy_document" "policy" {
  statement {
    sid = "AllowAssumeRoleWithMFA"
    
    actions = [
      "sts:AssumeRole"
    ]
    principals {
      type        = "AWS"
      identifiers = [
        "arn:aws:iam::ACCOUNT_ID:user/dev1"
      ]
    }
    
    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = [
        "true"
      ]
    }
    
  }
}
