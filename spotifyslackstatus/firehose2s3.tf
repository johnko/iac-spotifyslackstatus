locals {
  firehose2s3_hellolambda_name       = "${aws_lambda_function.lambdahello.name}-firehose2s3"
  loggroup_firehose2s3loglambda_name = "/aws/kinesisfirehose/${local.firehose2s3_hellolambda_name}"
}

##### Firehose LogGroup
resource "aws_cloudwatch_log_group" "loggroup_firehose2s3loglambda" {
  name              = local.loggroup_firehose2s3loglambda_name
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_spotifyslackstatus.arn
  tags = {
    Name               = local.loggroup_firehose2s3loglambda_name
    dataclassification = "restricted"
  }
}
####################
##### Firehose
resource "aws_kinesis_firehose_delivery_stream" "firehose2s3_loglambda" {
  name        = local.firehose2s3_hellolambda_name
  destination = "extended_s3"
  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"                 # or AWS_OWNED_CMK
    key_arn  = aws_kms_key.cmk_spotifyslackstatus.arn # comment this out if you want to use AWS_OWNED_CMK
  }
  extended_s3_configuration {
    role_arn           = aws_iam_role.role_firehose2s3executelog.arn
    bucket_arn         = "arn:aws:s3:::${local.logbucket}"
    prefix             = "executelogs/lambda/${aws_lambda_function.lambdahello.name}/"
    compression_format = "GZIP"
    # kms_key_arn not used since logbucket is SSE-S3 / AES256
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.loggroup_firehose2s3loglambda.name
      log_stream_name = "logstream"
    }
  }
  tags = {
    Name               = local.firehose2s3_hellolambda_name
    dataclassification = "restricted"
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_firehose2s3executelog,
  ]
}
