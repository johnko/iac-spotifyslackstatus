locals {
  statebucket = "statebucket-${local.accountid}"
}

####################
##### State Bucket
resource "aws_s3_bucket" "statebucket" {
  bucket = local.statebucket
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = "aws:kms"
        kms_master_key_id = aws_kms_key.cmk_tfremotebackend.arn # comment this out if you want to use alias/aws/s3
      }
      bucket_key_enabled = true # encrypt with KMS per bucket instead of per object
    }
  }
  versioning {
    enabled = true
  }
  lifecycle_rule {
    id      = "oldversions"
    enabled = true
    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    noncurrent_version_transition {
      days          = 60
      storage_class = "GLACIER"
    }
    noncurrent_version_expiration {
      days = 2562 # delete objects matching this rule after 7 years * 366 days = 2562 days including leap years
    }
  }
  lifecycle_rule {
    id                                     = "incompleteuploads"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 366
  }
  logging {
    target_bucket = aws_s3_bucket.logbucket.id
    target_prefix = "accesslogs/s3/${local.statebucket}/"
  }
  tags = {
    Name               = local.statebucket
    dataclassification = "confidential"
  }
  depends_on = [
    aws_s3_bucket_public_access_block.blockpublic_logbucket,
    aws_s3_bucket_ownership_controls.bucketowner_logbucket,
    aws_s3_bucket_policy.bucketpolicy_logbucket,
  ]
}
resource "aws_s3_bucket_public_access_block" "blockpublic_statebucket" {
  bucket                  = aws_s3_bucket.statebucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "bucketowner_statebucket" {
  bucket = aws_s3_bucket.statebucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_policy" "bucketpolicy_statebucket" {
  bucket = aws_s3_bucket.statebucket.id
  # Can't use DenyUnEncryptedObjectUploads with Terraform S3 Backend yet https://docs.aws.amazon.com/AmazonS3/latest/userguide/UsingKMSEncryption.html#sse-kms-bucket-keys
  # https://aws.amazon.com/premiumsupport/knowledge-center/s3-bucket-store-kms-encrypted-objects/
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Id" : "PutObjectPolicy",
    "Statement" : [
      {
        "Sid" : "DenyWrongKMS",
        "Effect" : "Deny",
        "Principal" : "*",
        "Action" : "s3:PutObject",
        "Resource" : "${aws_s3_bucket.statebucket.arn}/*",
        "Condition" : {
          "StringNotLikeIfExists" : {
            "s3:x-amz-server-side-encryption-aws-kms-key-id" : "${aws_kms_key.cmk_tfremotebackend.arn}"
          }
        }
      }
    ]
  })
}
