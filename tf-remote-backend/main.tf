locals {
  statebucket    = "statebucket-${local.accountid}"
  statelocktable = "statelock-${local.accountid}"
}

####################
##### Log Bucket
resource "aws_s3_bucket" "logbucket" {
  bucket = local.logbucket
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        # You can use default bucket encryption on the target bucket only if you use AES256 (SSE-S3). Default encryption with AWS KMS keys (SSE-KMS) is not supported.
        # https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
        sse_algorithm = "AES256"
      }
    }
  }
  # You can't enable S3 Object Lock on the target bucket.
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
  # object_lock_configuration {
  #   object_lock_enabled = "No"
  # }
  lifecycle_rule {
    id      = "accesslogs"
    enabled = true
    prefix  = "accesslogs/"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60
      storage_class = "GLACIER"
    }
    expiration {
      days = 2562 # delete objects matching this rule after 7 years * 366 days = 2562 days including leap years
    }
  }
  lifecycle_rule {
    id      = "executelogs/"
    enabled = true
    prefix  = "executelogs//"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 60
      storage_class = "GLACIER"
    }
    expiration {
      days = 2562 # delete objects matching this rule after 7 years * 366 days = 2562 days including leap years
    }
  }
  lifecycle_rule {
    id                                     = "incompleteuploads"
    enabled                                = true
    abort_incomplete_multipart_upload_days = 366
  }
  tags = {
    Name               = local.logbucket
    dataclassification = "restricted"
  }
}
resource "aws_s3_bucket_public_access_block" "logbucket_block" {
  bucket                  = aws_s3_bucket.logbucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "logbucket_owner" {
  bucket = aws_s3_bucket.logbucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}
resource "aws_s3_bucket_policy" "allow_logging" {
  bucket = aws_s3_bucket.logbucket.id
  # https://docs.aws.amazon.com/AmazonS3/latest/userguide/enable-server-access-logging.html
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "S3ServerAccessLogsPolicy",
      "Effect": "Allow",
      "Principal": {
        "Service": "logging.s3.amazonaws.com"
      },
      "Action": "s3:PutObject",
      "Resource": "${aws_s3_bucket.logbucket.arn}/accesslogs/*",
      "Condition": {
        "StringEquals": {
          "aws:SourceAccount": "${local.accountid}"
        }
      }
    }
  ]
}
EOF
}

####################
##### State Bucket
resource "aws_s3_bucket" "statebucket" {
  bucket = local.statebucket
  acl    = "private"
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
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
      days = 90 # delete old objects matching this rule after 90 days
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
    aws_s3_bucket_ownership_controls.logbucket_owner,
    aws_s3_bucket_policy.allow_logging,
  ]
}
resource "aws_s3_bucket_public_access_block" "statebucket_block" {
  bucket                  = aws_s3_bucket.statebucket.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
resource "aws_s3_bucket_ownership_controls" "statebucket_owner" {
  bucket = aws_s3_bucket.statebucket.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

####################
##### StateLock DynamoDB
resource "aws_dynamodb_table" "statelock_table" {
  name         = local.statelocktable
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  server_side_encryption {
    enabled = true
  }
  table_class = "STANDARD"
  tags = {
    Name               = local.statelocktable
    dataclassification = "confidential"
  }
}
