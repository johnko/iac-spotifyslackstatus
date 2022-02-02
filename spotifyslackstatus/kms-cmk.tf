locals {
  kmscloudwatch   = "cmk/cloudwatch"
}
####################
##### KMS CMK CloudWatch
resource "aws_kms_key" "cmk_cloudwatch" {
  description              = "cmk_cloudwatch"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy                   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Enable IAM User Permissions",
      "Action": "kms:*",
      "Effect": "Allow",
      "Principal": {
        "AWS": "arn:aws:iam::${local.accountid}:root"
      },
      "Resource": "*"
    },
    {
      "Sid": "AllowCloudWatchUse",
      "Action": [
        "kms:ReEncrypt*",
        "kms:GenerateDataKey*",
        "kms:Encrypt*",
        "kms:Describe*",
        "kms:Decrypt*"
      ],
      "Condition": {
        "ArnEquals": {
          "kms:EncryptionContext:aws:logs:arn": "arn:aws:logs:${local.region}:${local.accountid}:*"
        }
      },
      "Effect": "Allow",
      "Principal": {
        "Service": "logs.${local.region}.amazonaws.com"
      },
      "Resource": "*"
    }
  ]
}
EOF
  deletion_window_in_days  = 7
  is_enabled               = true
  enable_key_rotation      = true
  tags = {
    Name               = local.kmscloudwatch
    dataclassification = "restricted"
  }
}
resource "aws_kms_alias" "kmsalias_cloudwatch" {
  name          = "alias/${local.kmscloudwatch}"
  target_key_id = aws_kms_key.cmk_cloudwatch.key_id
}
