locals {
  role_fh2s3executelog_name   = "${local.app}-firehose2executelogs-role"
  policy_fh2s3executelog_name = "${local.app}-fh2s3executelog-policy"
}

####################
##### IAM for Firehose
resource "aws_iam_role" "role_fh2s3executelog" {
  name               = local.role_fh2s3executelog_name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowFirehoseServiceAssumeRole",
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    Name               = local.role_fh2s3executelog_name
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "policy_fh2s3executelog" {
  name        = local.policy_fh2s3executelog_name
  path        = "/"
  description = "Let Firehose write to logbucket"
  # Don't allow logs:CreateLogGroup because we create the encrypted loggroup_lambda
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaCreateLogs",
      "Action": [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:*:${local.accountid}:*"
    },
    {
      "Sid": "AllowWriteToBucket",
      "Action": [
        "s3:PutObject"
      ],
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${local.logbucket}/accesslogs/*",
        "arn:aws:s3:::${local.logbucket}/executelogs/*",
      ]
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_fh2s3executelog" {
  role       = aws_iam_role.role_fh2s3executelog.name
  policy_arn = aws_iam_policy.policy_fh2s3executelog.arn
}
