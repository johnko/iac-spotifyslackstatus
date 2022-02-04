locals {
  alias_cmkspotifyslackstatus = "cmk/${local.app}"
}

####################
##### KMS CMK CloudWatch
resource "aws_kms_key" "cmk_spotifyslackstatus" {
  description              = local.alias_cmkspotifyslackstatus
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "Enable IAM User Permissions",
        "Action" : "kms:*",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "arn:aws:iam::${local.accountid}:root"
        },
        "Resource" : "*"
      },
      {
        "Sid" : "AllowCloudWatchUse",
        "Action" : [
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:Encrypt*",
          "kms:Describe*",
          "kms:Decrypt*"
        ],
        "Condition" : {
          "ArnEquals" : {
            "kms:EncryptionContext:aws:logs:arn" : "arn:aws:logs:*:${local.accountid}:*"
          }
        },
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "logs.amazonaws.com"
        },
        "Resource" : "*"
      }
    ]
  })
  deletion_window_in_days = 7
  is_enabled              = true
  enable_key_rotation     = true
  tags = {
    Name               = local.alias_cmkspotifyslackstatus
    dataclassification = "restricted"
  }
}
resource "aws_kms_alias" "alias_spotifyslackstatus" {
  name          = "alias/${local.alias_cmkspotifyslackstatus}"
  target_key_id = aws_kms_key.cmk_spotifyslackstatus.key_id
}
