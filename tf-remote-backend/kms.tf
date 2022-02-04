locals {
  alias_cmktfremotebackend = "cmk/tf-remote-backend"
}

####################
##### KMS CMK CloudWatch
resource "aws_kms_key" "cmk_tfremotebackend" {
  description              = local.alias_cmktfremotebackend
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
        "Sid" : "Allow access through Amazon DynamoDB for all principals in the account that are authorized to use Amazon DynamoDB",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "${local.whoamiarn}"
        },
        "Action" : [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
          "kms:CreateGrant"
        ],
        "Resource" : "*",
        "Condition" : {
          "StringLike" : {
            "kms:ViaService" : "dynamodb.*.amazonaws.com"
          }
        }
      },
      {
        "Sid" : "Allow administrators to view the KMS key and revoke grants",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "${local.whoamiarn}"
        },
        "Action" : [
          "kms:Describe*",
          "kms:Get*",
          "kms:List*",
          "kms:RevokeGrant"
        ],
        "Resource" : "*"
      }
    ]
  })
  deletion_window_in_days = 7
  is_enabled              = true
  enable_key_rotation     = true
  tags = {
    Name               = local.alias_cmktfremotebackend
    dataclassification = "restricted"
  }
}
resource "aws_kms_alias" "alias_tfremotebackend" {
  name          = "alias/${local.alias_cmktfremotebackend}"
  target_key_id = aws_kms_key.cmk_tfremotebackend.key_id
}
