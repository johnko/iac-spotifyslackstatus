locals {
  loggroup_apigw_name       = "/aws/apigateway/${local.apigw_name}"
  apigw_name                = "${local.app}-apigw"
  stage_apigw_name          = "${local.app}-apigw-stage"
  loggroup_fh2s3apigw_name  = "/aws/kinesisfirehose/${local.fh2s3_apigw_name}"
  fh2s3_apigw_name          = "${local.apigw_name}-fh2s3"
  subfilter_cw2fhapigw_name = "${local.apigw_name}-subfil"
}

##### APIGW LogGroup
resource "aws_cloudwatch_log_group" "loggroup_apigw" {
  name              = local.loggroup_apigw_name
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_spotifyslackstatus.arn
  tags = {
    Name               = local.loggroup_apigw_name
    dataclassification = "restricted"
  }
}
####################
##### API Gateway
resource "aws_apigatewayv2_api" "apigw" {
  name          = local.apigw_name
  description   = "A Public API to Lambda"
  protocol_type = "HTTP"
  # cors_configuration {
  #   allow_origins = ""
  # }
  # body # Don't use `body`, use `aws_apigatewayv2_integration` and `aws_apigatewayv2_route` instead
  tags = {
    Name               = local.apigw_name
    dataclassification = "public"
  }
  depends_on = [
    aws_cloudwatch_log_group.loggroup_apigw,
    aws_cloudwatch_log_subscription_filter.subfilter_cw2fh_apigw,
  ]
}
resource "aws_apigatewayv2_stage" "stage_apigw" {
  api_id      = aws_apigatewayv2_api.apigw.id
  name        = local.stage_apigw_name
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.loggroup_apigw.arn
    format = jsonencode({
      requestId               = "$context.requestId"
      sourceIp                = "$context.identity.sourceIp"
      requestTime             = "$context.requestTime"
      protocol                = "$context.protocol"
      httpMethod              = "$context.httpMethod"
      resourcePath            = "$context.resourcePath"
      routeKey                = "$context.routeKey"
      status                  = "$context.status"
      responseLength          = "$context.responseLength"
      integrationErrorMessage = "$context.integrationErrorMessage"
    })
  }
  tags = {
    Name               = local.stage_apigw_name
    dataclassification = "public"
  }
}

####################
##### Firehose LogGroup
resource "aws_cloudwatch_log_group" "loggroup_fh2s3apigw" {
  name              = local.loggroup_fh2s3apigw_name
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_spotifyslackstatus.arn
  tags = {
    Name               = local.loggroup_fh2s3apigw_name
    dataclassification = "restricted"
  }
}
##### Firehose for APIGW
resource "aws_kinesis_firehose_delivery_stream" "fh2s3_apigw" {
  name        = local.fh2s3_apigw_name
  destination = "extended_s3"
  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"                 # or AWS_OWNED_CMK
    key_arn  = aws_kms_key.cmk_spotifyslackstatus.arn # comment this out if you want to use AWS_OWNED_CMK
  }
  extended_s3_configuration {
    role_arn           = aws_iam_role.role_fh2s3executelog.arn
    bucket_arn         = "arn:aws:s3:::${local.logbucket}"
    prefix             = "accesslogs/apigw/${local.apigw_name}/"
    compression_format = "GZIP"
    # kms_key_arn not used since logbucket is SSE-S3 / AES256
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.loggroup_fh2s3apigw.name
      log_stream_name = "logstream"
    }
  }
  tags = {
    Name               = local.fh2s3_apigw_name
    dataclassification = "restricted"
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_fh2s3executelog,
  ]
}
##### CloudWatch SubscriptionFilter forwards logs to firehose to bucket
resource "aws_cloudwatch_log_subscription_filter" "subfilter_cw2fh_apigw" {
  name           = local.subfilter_cw2fhapigw_name
  role_arn       = aws_iam_role.role_cw2fh.arn
  log_group_name = aws_cloudwatch_log_group.loggroup_apigw.name
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
  filter_pattern  = " " # all events
  destination_arn = aws_kinesis_firehose_delivery_stream.fh2s3_apigw.arn
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_cw2fh,
    aws_iam_role_policy_attachment.attach_role_policy_fh2s3executelog,
  ]
}

####################
##### Output
output "base_url" {
  description = "Base URL for API Gateway stage."
  value       = aws_apigatewayv2_stage.stage_apigw.invoke_url
}
