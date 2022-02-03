locals {
  lambda_hello_name         = "${local.app}-lambdahello"
  loggroup_lambdahello_name = "/aws/lambda/${local.lambda_hello_name}"
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
    aws_cloudwatch_log_group.loggroup_lambda,
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
