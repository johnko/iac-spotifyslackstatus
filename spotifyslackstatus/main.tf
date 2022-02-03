locals {
  app = "spotifyslackstatus"
}

module "hello" {
  source = "./modules/lambda_api_route"

  service_name            = "hello"
  lambda_handler          = "index.hello"
  lambda_runtime          = "python3.8"
  lambda_zip_file         = "index.zip"
  apigw_route_http_method = "GET"
  apigw_route_http_path   = "/hello"

  app                          = local.app
  iam_role_cw2fh_arn           = aws_iam_role.role_cw2fh.arn
  iam_role_fh2s3executelog_arn = aws_iam_role.role_fh2s3executelog.arn
  iam_role_lambda_arn          = aws_iam_role.role_lambda.arn
  kms_key_arn                  = aws_kms_key.cmk_spotifyslackstatus.arn
  logbucket                    = local.logbucket
  apigw_id                     = aws_apigatewayv2_api.apigw.id
  apigw_exec_arn               = aws_apigatewayv2_api.apigw.execution_arn
  session_dynamodb_table       = aws_dynamodb_table.statelock_table.name
  session_dynamodb_region      = local.region

  depends_on = [
    aws_iam_role_policy_attachment.attach_role_policy_lambda,
    aws_iam_role_policy_attachment.attach_role_policy_fh2s3executelog,
    aws_iam_role_policy_attachment.attach_role_policy_cw2fh,
  ]
}
