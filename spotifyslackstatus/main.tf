locals {
  sessiontable    = "spotifyslackstatus-flask_sessions-${local.accountid}"
  lambdafunc      = "spotifyslackstatus-lambda-func"
  lambdarole      = "spotifyslackstatus-lambda-role"
  lambdalogpolicy = "spotifyslackstatus-lambda-log-policy"
  kmscloudwatch   = "cmk/cloudwatch"
  firehosetos3    = "spotifyslackstatus-firehose-to-s3"
  firehoserole    = "spotifyslackstatus-firehose-role"
  firehosepolicy  = "spotifyslackstatus-firehose-policy"
  firehoseprefix  = "executelogs/lambda/${local.lambdafunc}/"
  lambdalogfilter = "spotifyslackstatus-logfilter"
  lambdaloggroup  = "/aws/lambda/${local.lambdafunc}"
  logfilterrole   = "spotifyslackstatus-logfilter-role"
  logfilterpolicy = "spotifyslackstatus-logfilter-policy"
}




####################
##### StateLock DynamoDB
resource "aws_dynamodb_table" "statelock_table" {
  name         = local.sessiontable
  billing_mode = "PAY_PER_REQUEST"
  # https://pypi.org/project/flask-dynamodb-sessions/
  # aws dynamodb create-table --key-schema "AttributeName=id,KeyType=HASH" \
  # --attribute-definitions "AttributeName=id,AttributeType=S" \
  # --provisioned-throughput "ReadCapacityUnits=5,WriteCapacityUnits=5" \
  # --table-name flask_sessions
  hash_key = "id"
  attribute {
    name = "id"
    type = "S"
  }
  # aws dynamodb update-time-to-live --time-to-live-specification 'Enabled=true,AttributeName=ttl' --table-name flask_sessions
  ttl {
    enabled        = true
    attribute_name = "ttl"
  }
  server_side_encryption {
    enabled = true
  }
  table_class = "STANDARD"
  tags = {
    Name               = local.sessiontable
    dataclassification = "restricted"
  }
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




####################
##### LogGroups
# Lambda Logs
resource "aws_cloudwatch_log_group" "lambda_loggroup" {
  name              = local.lambdaloggroup
  retention_in_days = 90
  kms_key_id        = "arn:aws:kms:${local.region}:${local.accountid}:alias/${local.kmscloudwatch}"
  tags = {
    Name               = local.lambdaloggroup
    dataclassification = "restricted"
  }
  depends_on = [
    aws_kms_alias.kmsalias_cloudwatch,
  ]
}
# Firehose Logs
resource "aws_cloudwatch_log_group" "firehose_loggroup" {
  name              = "/aws/kinesisfirehose/${local.firehosetos3}"
  retention_in_days = 90
  kms_key_id        = "arn:aws:kms:${local.region}:${local.accountid}:alias/${local.kmscloudwatch}"
  tags = {
    Name               = "/aws/kinesisfirehose/${local.firehosetos3}"
    dataclassification = "restricted"
  }
  depends_on = [
    aws_kms_alias.kmsalias_cloudwatch,
  ]
}




####################
##### Firehose
resource "aws_kinesis_firehose_delivery_stream" "firehose_to_s3" {
  name        = local.firehosetos3
  destination = "extended_s3"
  server_side_encryption {
    enabled  = true
    key_type = "AWS_OWNED_CMK"
  }
  extended_s3_configuration {
    role_arn           = aws_iam_role.firehose_role.arn
    bucket_arn         = "arn:aws:s3:::${local.logbucket}"
    prefix             = local.firehoseprefix
    compression_format = "GZIP"
    kms_key_arn        = "arn:aws:kms:${local.region}:${local.accountid}:alias/aws/s3"
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = "/aws/kinesisfirehose/${local.firehosetos3}"
      log_stream_name = "logstream"
    }
  }
  tags = {
    Name               = local.firehosetos3
    dataclassification = "restricted"
  }
  depends_on = [
    aws_cloudwatch_log_group.firehose_loggroup,
  ]
}
resource "aws_iam_role" "firehose_role" {
  name               = local.firehoserole
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
    Name               = local.firehoserole
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "firehose_policy" {
  name        = local.firehosepolicy
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaCreateLogs",
      "Action": [
        "logs:CreateLogGroup",
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
      "Resource": "arn:aws:s3:::${local.logbucket}/${local.firehoseprefix}*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "firehose_attach_policy" {
  role       = aws_iam_role.firehose_role.name
  policy_arn = aws_iam_policy.firehose_policy.arn
}




####################
##### SubscriptionFilter
# CloudWatch SubscriptionFilter forwards logs to firehose to bucket
resource "aws_cloudwatch_log_subscription_filter" "lambda_logfilter" {
  name           = local.lambdalogfilter
  role_arn       = aws_iam_role.logfilter_role.arn
  log_group_name = local.lambdaloggroup
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
  filter_pattern  = " " # all events
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose_to_s3.arn
  depends_on = [
    aws_cloudwatch_log_group.lambda_loggroup,
  ]
}
resource "aws_iam_role" "logfilter_role" {
  name               = local.logfilterrole
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
    Name               = local.logfilterrole
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "logfilter_policy" {
  name        = local.logfilterpolicy
  path        = "/"
  description = "IAM policy for logging from a lambda"
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
resource "aws_iam_role_policy_attachment" "logfilter_attach_policy" {
  role       = aws_iam_role.logfilter_role.name
  policy_arn = aws_iam_policy.logfilter_policy.arn
}




####################
# ##### Lambda
# resource "aws_lambda_function" "lambda" {
#   function_name = local.lambdafunc
#   role          = aws_iam_role.lambda_role.arn
#   handler  = "index.lambda_handler"
#   filename = "lambda_function_payload.zip"
#   # The filebase64sha256() function is available in Terraform 0.11.12 and later
#   # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
#   # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
#   source_code_hash = filebase64sha256("lambda_function_payload.zip")
#   runtime = "python3.8"
#   environment {
#     variables = {
#       SESSION_DYNAMODB_TABLE  = local.sessiontable,
#       SESSION_DYNAMODB_REGION = local.region,
#     }
#   }
#   tags = {
#     Name               = local.lambdafunc
#     dataclassification = "public"
#   }
#   depends_on = [
#     aws_iam_role_policy_attachment.lambda_attach_logging_policy,
#     aws_cloudwatch_log_group.lambda_loggroup,
#   ]
# }
resource "aws_iam_role" "lambda_role" {
  name               = local.lambdarole
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaServiceAssumeRole",
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ]
}
EOF
  tags = {
    Name               = local.lambdarole
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "lambda_logging_policy" {
  name        = local.lambdalogpolicy
  path        = "/"
  description = "IAM policy for logging from a lambda"
  policy      = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaCreateLogs",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Effect": "Allow",
      "Resource": "arn:aws:logs:*:${local.accountid}:*"
    }
  ]
}
EOF
}
resource "aws_iam_role_policy_attachment" "lambda_attach_logging_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}
