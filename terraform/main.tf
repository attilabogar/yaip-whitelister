# The configuration for this backend will be filled in by Terragrunt
terraform {
  backend "s3" {}
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

resource "aws_s3_bucket" "edge_src" {
  bucket = var.bucket_src
}

resource "aws_s3_bucket_public_access_block" "edge_src" {
  bucket                  = aws_s3_bucket.edge_src.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket" "edge_dst" {
  bucket = var.bucket_dst
}

data "aws_iam_policy_document" "edge_user_src" {
  statement {
    sid       = "SRC0"
    effect    = "Allow"
    actions   = ["s3:GetBucketLocation"]
    resources = [aws_s3_bucket.edge_src.arn]
  }
  statement {
    sid     = "SRC1"
    effect  = "Allow"
    actions = ["s3:PutObject", "s3:DeleteObject"]
    resources = [
      "${aws_s3_bucket.edge_src.arn}/ipv4/$${aws:username}",
      "${aws_s3_bucket.edge_src.arn}/ipv6/$${aws:username}"
    ]
  }
  depends_on = [aws_s3_bucket.edge_src]
}

resource "aws_iam_policy" "edge_policy_src" {
  name        = "edge_user_policy_src"
  path        = "/"
  description = "EDGE SRC Policy"
  policy      = data.aws_iam_policy_document.edge_user_src.json
}

resource "aws_iam_user" "edge_user" {
  count = length(var.users)
  name  = var.users[count.index]
  path  = "/"
}

resource "aws_iam_policy_attachment" "edge_user_policy_attachment" {
  count      = length(var.users)
  name       = "edge_user_src_policy_attachment"
  users      = var.users
  policy_arn = aws_iam_policy.edge_policy_src.arn
  depends_on = [aws_iam_user.edge_user]
}
