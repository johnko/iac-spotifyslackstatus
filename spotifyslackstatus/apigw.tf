locals {
  apigw_name          = "${local.app}-apigw"
  stage_apigw_name    = "${local.app}-apigw-stage"
  loggroup_apigw_name = "/aws/apigateway/${local.apigw}"
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
