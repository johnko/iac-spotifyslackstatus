locals {
  lambdafunc      = "spotifyslackstatus-lambda-func"
  lambdarole      = "spotifyslackstatus-lambda-role"
  lambdalogpolicy = "spotifyslackstatus-lambda-log-policy"
  firehosetos3    = "spotifyslackstatus-firehose-to-s3"
  firehoserole    = "spotifyslackstatus-firehose-role"
  firehosepolicy  = "spotifyslackstatus-firehose-policy"
  firehoseprefix  = "executelogs/lambda/${local.lambdafunc}/"
  lambdalogfilter = "spotifyslackstatus-logfilter"
  lambdaloggroup  = "/aws/lambda/${local.lambdafunc}"
  logfilterrole   = "spotifyslackstatus-logfilter-role"
  logfilterpolicy = "spotifyslackstatus-logfilter-policy"
  apigw           = "spotifyslackstatus-apigw"
}




####################
##### LogGroups
# Lambda Logs
resource "aws_cloudwatch_log_group" "lambda_loggroup" {
  name              = local.lambdaloggroup
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_cloudwatch.arn
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
  kms_key_id        = aws_kms_key.cmk_cloudwatch.arn
  tags = {
    Name               = "/aws/kinesisfirehose/${local.firehosetos3}"
    dataclassification = "restricted"
  }
  depends_on = [
    aws_kms_alias.kmsalias_cloudwatch,
  ]
}
# APIGW Logs
resource "aws_cloudwatch_log_group" "apigw_loggroup" {
  name              = "/aws/apigateway/${local.apigw}"
  retention_in_days = 90
  kms_key_id        = aws_kms_key.cmk_cloudwatch.arn
  tags = {
    Name               = "/aws/apigateway/${local.apigw}"
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
    aws_iam_role_policy_attachment.firehose_attach_policy,
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
    aws_iam_role_policy_attachment.logfilter_attach_policy,
    aws_iam_role_policy_attachment.firehose_attach_policy,
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
##### Lambda
resource "aws_lambda_function" "lambda" {
  function_name = local.lambdafunc
  role          = aws_iam_role.lambda_role.arn
  handler       = "index.hello"
  filename      = "lambda_function_payload.zip"
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")
  runtime          = "python3.8"
  environment {
    variables = {
      SESSION_DYNAMODB_TABLE  = local.sessiontable,
      SESSION_DYNAMODB_REGION = local.region,
    }
  }
  tags = {
    Name               = local.lambdafunc
    dataclassification = "public"
  }
  depends_on = [
    aws_iam_role_policy_attachment.lambda_attach_logging_policy,
    aws_cloudwatch_log_group.lambda_loggroup,
  ]
}
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




####################
##### API Gateway
resource "aws_apigatewayv2_api" "apigw" {
  name          = local.apigw
  description   = local.apigw
  protocol_type = "HTTP"
  # cors_configuration {
  #   allow_origins = ""
  # }
  # body # Don't use `body`, use `aws_apigatewayv2_integration` and `aws_apigatewayv2_route` instead
  tags = {
    Name               = local.apigw
    dataclassification = "public"
  }
  depends_on = [
    aws_lambda_function.lambda,
    aws_cloudwatch_log_group.apigw_loggroup,
  ]
}
resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.apigw.id
  name        = "${local.apigw}-stage"
  auto_deploy = true
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.apigw_loggroup.arn
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
}
resource "aws_apigatewayv2_integration" "hello" {
  api_id             = aws_apigatewayv2_api.apigw.id
  integration_uri    = aws_lambda_function.lambda.invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}
resource "aws_apigatewayv2_route" "hello" {
  api_id    = aws_apigatewayv2_api.apigw.id
  route_key = "GET /hello"
  target    = "integrations/${aws_apigatewayv2_integration.hello.id}"
}
resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.apigw.execution_arn}/*/*"
}
output "base_url" {
  description = "Base URL for API Gateway stage."
  value       = aws_apigatewayv2_stage.stage.invoke_url
}

# TODO convert SubscriptionFilter into module
# TODO use SubscriptionFilter module to logfilter for apigw LogGroup
