locals {
  loggroup_lambdahello_name = "/aws/lambda/${local.lambda_hello_name}"
  lambda_hello_name         = "${local.app}-lambdahello"
  loggroup_fh2s3lambdahello_name = "/aws/kinesisfirehose/${local.fh2s3_lambdahello_name}"
  fh2s3_lambdahello_name       = "${aws_lambda_function.lambdahello.function_name}-firehose2s3"
  subfilter_lambdahello_name = "${local.lambda_hello_name}-subfil"
}

##### Lambda LogGroup
resource "aws_cloudwatch_log_group" "loggroup_lambdahello" {
  name              = local.loggroup_lambdahello_name
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_spotifyslackstatus.arn
  tags = {
    Name               = local.loggroup_lambdahello_name
    dataclassification = "restricted"
  }
}
####################
##### Lambda
resource "aws_lambda_function" "lambdahello" {
  function_name = local.lambda_hello_name
  role          = aws_iam_role.role_lambda.arn
  handler       = "index.hello"
  filename      = "index.zip"
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("index.zip")
  runtime          = "python3.8"
  environment {
    variables = {
      SESSION_DYNAMODB_REGION = local.region,
      SESSION_DYNAMODB_TABLE  = aws_dynamodb_table.statelock_table.name,
    }
  }
  tags = {
    Name               = local.lambda_hello_name
    dataclassification = "public"
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_lambda,
    aws_cloudwatch_log_group.loggroup_lambdahello,
  ]
}

####################
##### Firehose LogGroup
resource "aws_cloudwatch_log_group" "loggroup_firehose2s3loglambda" {
  name              = local.loggroup_fh2s3lambdahello_name
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_spotifyslackstatus.arn
  tags = {
    Name               = local.loggroup_fh2s3lambdahello_name
    dataclassification = "restricted"
  }
}
##### Firehose repeat for each lambda
resource "aws_kinesis_firehose_delivery_stream" "firehose2s3_loglambda" {
  name        = local.fh2s3_lambdahello_name
  destination = "extended_s3"
  server_side_encryption {
    enabled  = true
    key_type = "CUSTOMER_MANAGED_CMK"                 # or AWS_OWNED_CMK
    key_arn  = aws_kms_key.cmk_spotifyslackstatus.arn # comment this out if you want to use AWS_OWNED_CMK
  }
  extended_s3_configuration {
    role_arn           = aws_iam_role.role_firehose2s3executelog.arn
    bucket_arn         = "arn:aws:s3:::${local.logbucket}"
    prefix             = "executelogs/lambda/${aws_lambda_function.lambdahello.function_name}/"
    compression_format = "GZIP"
    # kms_key_arn not used since logbucket is SSE-S3 / AES256
    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.loggroup_firehose2s3loglambda.name
      log_stream_name = "logstream"
    }
  }
  tags = {
    Name               = local.fh2s3_lambdahello_name
    dataclassification = "restricted"
  }
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_firehose2s3executelog,
  ]
}
##### CloudWatch SubscriptionFilter forwards logs to firehose to bucket
resource "aws_cloudwatch_log_subscription_filter" "subfilter_cw2fh_lambdahello" {
  name           = local.subfilter_lambdahello_name
  role_arn       = aws_iam_role.role_cw2fh.arn
  log_group_name = aws_cloudwatch_log_group.loggroup_lambda.name
  # https://docs.aws.amazon.com/AmazonCloudWatch/latest/logs/FilterAndPatternSyntax.html
  filter_pattern  = " " # all events
  destination_arn = aws_kinesis_firehose_delivery_stream.firehose2s3_loglambda.arn
  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_cw2fh,
    aws_iam_role_policy_attachment.attach_role_policy_firehose2s3loglambda,
  ]
}

####################
##### Hello Lambda + APIGW integration
resource "aws_apigatewayv2_route" "route_hello" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.integration_hello.id}"
}
resource "aws_apigatewayv2_integration" "integration_hello" {
  api_id             = aws_apigatewayv2_api.apigw.id
  integration_uri    = aws_lambda_function.lambdahello.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}
##### Lambda Permission
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambdahello.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apigw.execution_arn}/*/*"
}
