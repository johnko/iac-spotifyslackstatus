locals {
  app = "spotifyslackstatus"

}

resource "aws_s3_bucket_object" "lambdaobject" {
  bucket = aws_s3_bucket.lambdabucket.id
  key    = "lambda/index.zip"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag   = filemd5("index.zip")
  source = "index.zip"
}

module "hello" {
  source = "./modules/lambda_api_route"

  service_name   = "hello"
  lambda_handler = "index.hello"
  lambda_runtime = "python3.8"
  # lambda_zip_file         = "index.zip"
  lambda_s3_bucket        = aws_s3_bucket.lambdabucket.id
  lambda_s3_object        = aws_s3_bucket_object.lambdaobject.id
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

# module "goodbye" {
#   source = "./modules/lambda_api_route"

#   service_name   = "goodbye"
#   lambda_handler = "index.goodbye"
#   lambda_runtime = "python3.8"
#   # lambda_zip_file         = "index.zip"
#   lambda_s3_bucket = aws_s3_bucket.lambdabucket.id
#   lambda_s3_object = aws_s3_bucket_object.lambdaobject.id
#   apigw_route_http_method = "GET"
#   apigw_route_http_path   = "/goodbye"

#   app                          = local.app
#   iam_role_cw2fh_arn           = aws_iam_role.role_cw2fh.arn
#   iam_role_fh2s3executelog_arn = aws_iam_role.role_fh2s3executelog.arn
#   iam_role_lambda_arn          = aws_iam_role.role_lambda.arn
#   kms_key_arn                  = aws_kms_key.cmk_spotifyslackstatus.arn
#   logbucket                    = local.logbucket
#   apigw_id                     = aws_apigatewayv2_api.apigw.id
#   apigw_exec_arn               = aws_apigatewayv2_api.apigw.execution_arn
#   session_dynamodb_table       = aws_dynamodb_table.statelock_table.name
#   session_dynamodb_region      = local.region

#   depends_on = [
#     aws_iam_role_policy_attachment.attach_role_policy_lambda,
#     aws_iam_role_policy_attachment.attach_role_policy_fh2s3executelog,
#     aws_iam_role_policy_attachment.attach_role_policy_cw2fh,
#   ]
# }

# TODO convert to Lambda Layer to reduce Code storage
