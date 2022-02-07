locals {
  app                  = var.app
  loggroup_lambda_name = "/aws/lambda/${local.lambda_name}"
  loggroup_lambdainsights_name = "/aws/lambda-insights/${local.lambda_name}"
  lambda_name          = "${local.app}-${var.service_name}"
  loggroup_fh2s3_name  = "/aws/kinesisfirehose/${local.fh2s3_name}"
  fh2s3_name           = "${aws_lambda_function.lambda.function_name}-fh2s3"
  subfilter_cw2fh_name = "${local.lambda_name}-subfil"
}

##### Lambda LogGroup
resource "aws_cloudwatch_log_group" "loggroup_lambda" {
  name              = local.loggroup_lambda_name
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn
  tags = {
    Name               = local.loggroup_lambda_name
    dataclassification = "restricted"
  }
}
##### Lambda Insights LogGroup
resource "aws_cloudwatch_log_group" "loggroup_lambdainsights" {
  name              = local.loggroup_lambdainsights_name
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn
  tags = {
    Name               = local.loggroup_lambdainsights_name
    dataclassification = "restricted"
  }
}
####################
##### Lambda
resource "aws_lambda_function" "lambda" {
  function_name = local.lambda_name
  role          = var.iam_role_lambda_arn
  handler       = var.lambda_handler
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  # filename      = var.lambda_zip_file
  # source_code_hash = filebase64sha256(var.lambda_zip_file)
  s3_bucket = var.lambda_s3_bucket
  s3_key = var.lambda_s3_object
  # https://docs.aws.amazon.com/lambda/latest/dg/monitoring-insights.html
  # TODOUPDATE https://docs.aws.amazon.com/AmazonCloudWatch/latest/monitoring/Lambda-Insights-extension-versionsx86-64.html
  layers = [ "arn:aws:lambda:ca-central-1:580247275435:layer:LambdaInsightsExtension:16" ]
  runtime          = var.lambda_runtime
  timeout          = 30 # seconds
  kms_key_arn      = var.kms_key_arn # comment this out if you want to use AWS managed key
  environment {
    variables = {
      SESSION_DYNAMODB_REGION = var.session_dynamodb_region,
      SESSION_DYNAMODB_TABLE  = var.session_dynamodb_table,
    }
  }
  tags = {
    Name               = local.lambda_name
    dataclassification = "public"
  }
  depends_on = [
    aws_cloudwatch_log_group.loggroup_lambda,
  ]
}
resource "aws_lambda_function_event_invoke_config" "example" {
  function_name                = aws_lambda_function.lambda.function_name
  maximum_event_age_in_seconds = 300
  maximum_retry_attempts       = 0
}

####################
##### Firehose LogGroup
resource "aws_cloudwatch_log_group" "loggroup_fh2s3" {
  name              = local.loggroup_fh2s3_name
  retention_in_days = 90
  kms_key_id        = var.kms_key_arn
  tags = {
    Name               = local.loggroup_fh2s3_name
    dataclassification = "restricted"
  }
}
##### Firehose repeat for each lambda
resource "aws_kinesis_firehose_delivery_stream" "fh2s3" {
  name        = local.fh2s3_name
  destination = "extended_s3"
  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK" # or AWS_OWNED_CMK
    key_arn  = var.kms_key_arn        # comment this out if you want to use AWS_OWNED_CMK
  }
  extended_s3_configuration {
    role_arn           = var.iam_role_fh2s3executelog_arn
    bucket_arn         = "arn:aws:s3:::${var.logbucket}"
    prefix             = "executelogs/lambda/${aws_lambda_function.lambda.function_name}/"
    compression_format = "GZIP"
    # kms_key_arn not used since logbucket is SSE-S3 / AES256
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.loggroup_fh2s3.name
      log_stream_name = "logstream"
    }
  }
  tags = {
    Name               = local.fh2s3_name
    dataclassification = "restricted"
  }
}
##### CloudWatch SubscriptionFilter forwards logs to firehose to bucket
resource "aws_cloudwatch_log_subscription_filter" "subfilter_cw2fh" {
  name           = local.subfilter_cw2fh_name
  role_arn       = var.iam_role_cw2fh_arn
  log_group_name = aws_cloudwatch_log_group.loggroup_lambda.name
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
  filter_pattern  = " " # all events
  destination_arn = aws_kinesis_firehose_delivery_stream.fh2s3.arn
}

####################
##### Lambda + APIGW integration
resource "aws_apigatewayv2_route" "route_lambda" {
  api_id    = var.apigw_id
  route_key = "${var.apigw_route_http_method} ${var.apigw_route_http_path}"
  target    = "integrations/${aws_apigatewayv2_integration.integration_lambda.id}"
}
resource "aws_apigatewayv2_integration" "integration_lambda" {
  api_id             = var.apigw_id
  integration_uri    = aws_lambda_function.lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}
##### Lambda Permission
resource "aws_lambda_permission" "perm_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${var.apigw_exec_arn}/*/*"
}
