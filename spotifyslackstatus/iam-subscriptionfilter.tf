locals {
  role_cw2fh_name   = "${local.app}-subfilter-role"
  policy_cw2fh_name = "${local.app}-cw2fh-policy"
}

####################
##### IAM for SubscriptionFilter
resource "aws_iam_role" "role_cw2fh" {
  name               = local.role_cw2fh_name
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowFirehoseServiceAssumeRole",
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    Name               = local.role_cw2fh_name
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "policy_cw2fh" {
  name        = local.policy_cw2fh_name
  path        = "/"
  description = "Let CloudWatch subscribe and write to Firehose"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowSubscribe",
      "Action": [
        "logs:PutSubscriptionFilter"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:*:${local.accountid}:*"
    },
    {
      "Sid": "AllowFirehoseAll",
      "Action": [
        "firehose:ListDeliveryStreams"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Sid": "AllowFirehosePutEvents",
      "Action": [
        "firehose:DescribeDeliveryStream",
        "firehose:PutRecord",
        "firehose:PutRecordBatch"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:firehose:*:${local.accountid}:*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_cw2fh" {
  role       = aws_iam_role.role_cw2fh.name
  policy_arn = aws_iam_policy.policy_cw2fh.arn
}
