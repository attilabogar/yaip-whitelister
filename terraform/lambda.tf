resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
POLICY
}

resource "aws_iam_policy" "lambda_s3" {
  name        = "lambda-s3-access"
  description = "Lambda to access S3 buckets"

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
        "Effect": "Allow",
        "Action": [
            "logs:*"
        ],
        "Resource": "arn:aws:logs:*:*:*"
    },
    {
        "Effect": "Allow",
        "Action": [ "s3:GetObject", "s3:DeleteObject" ],
        "Resource": "${aws_s3_bucket.edge_src.arn}/*"
    },
    {
        "Effect": "Allow",
        "Action": [ "s3:ListBucket" ],
        "Resource": "${aws_s3_bucket.edge_src.arn}"
    },
    {
        "Effect": "Allow",
        "Action": [ "s3:PutObject", "s3:PutObjectAcl" ],
        "Resource": "${aws_s3_bucket.edge_dst.arn}/*"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "edge_policy_attachment1" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "edge_policy_attachment2" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.lambda_s3.arn
}

data "template_file" "whitelist_handler" {
  template = file("whitelist.py.tpl")
  vars = {
    aws_region = var.aws_region
    bucket_src = var.bucket_src
    bucket_dst = var.bucket_dst
  }
}

data "archive_file" "whitelist_handler_lambda_package" {
  type        = "zip"
  output_path = "whitelist.zip"

  source {
    content  = data.template_file.whitelist_handler.rendered
    filename = "whitelist.py"
  }
}

resource "aws_lambda_function" "whitelist" {
  filename         = "whitelist.zip"
  function_name    = "whitelist"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "whitelist.lambda_handler"
  source_code_hash = data.archive_file.whitelist_handler_lambda_package.output_base64sha256
  publish          = true
  runtime          = "python3.9"
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.whitelist.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.edge_src.arn
  depends_on    = [aws_s3_bucket.edge_src]
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = aws_s3_bucket.edge_src.id

  lambda_function {
    lambda_function_arn = aws_lambda_function.whitelist.arn
    events              = ["s3:ObjectCreated:*", "s3:ObjectRemoved:*"]
  }

  depends_on = [aws_lambda_permission.allow_bucket]
}
