locals {
  app = "spotifyslackstatus"
}

####################
##### Output
output "base_url" {
  description = "Base URL for API Gateway stage."
  value       = aws_apigatewayv2_stage.stage_apigw.invoke_url
}

# TODO convert SubscriptionFilter into module
# TODO use SubscriptionFilter module to logfilter for apigw LogGroup
