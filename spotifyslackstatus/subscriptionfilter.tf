locals {
  subfilter_cw2fhlambdalog_name = "${local.app}-subfil"
  role_cw2fhlambdalog_name      = "${local.app}-subfil-role"
  policy_cw2fhlambdalog_name    = "${local.app}-subfil-policy"
}

####################
##### SubscriptionFilter
# CloudWatch SubscriptionFilter forwards logs to firehose to bucket
resource "aws_cloudwatch_log_subscription_filter" "subfilter_cw2fhlambdalog" {
  name           = local.subfilter_cw2fhlambdalog_name
  role_arn       = aws_iam_role.role_cw2fhlambdalog.arn
  log_group_name = aws_cloudwatch_log_group.loggroup_lambda.name
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
  filter_pattern  = " " # all events
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose2s3_loglambda.arn
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_cw2fhlambdalog,
    aws_iam_role_policy_attachment.attach_role_policy_firehose2s3loglambda,
  ]
}
resource "aws_iam_role" "role_cw2fhlambdalog" {
  name               = local.role_cw2fhlambdalog_name
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
    Name               = local.role_cw2fhlambdalog_name
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "policy_cw2fhlambdalog" {
  name        = local.policy_cw2fhlambdalog_name
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
resource "aws_iam_role_policy_attachment" "attach_role_policy_cw2fhlambdalog" {
  role       = aws_iam_role.role_cw2fhlambdalog.name
  policy_arn = aws_iam_policy.policy_cw2fhlambdalog.arn
}
