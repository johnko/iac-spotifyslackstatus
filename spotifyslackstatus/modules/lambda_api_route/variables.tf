variable "app" {
  type        = string
  description = "An app name. Will be used to prefix resource names."
}

variable "service_name" {
  type        = string
  description = "A service name. Will be used to suffix the Lambda name. Example: healthz"
}

variable "iam_role_cw2fh_arn" {
  type        = string
  description = "An ARN of an IAM Role for the SubscriptionFilter."
}

variable "iam_role_fh2s3executelog_arn" {
  type        = string
  description = "An ARN of an IAM Role for the Firehose."
}

variable "iam_role_lambda_arn" {
  type        = string
  description = "An ARN of an IAM Role for the Lambda."
}

variable "kms_key_arn" {
  type        = string
  description = "An ARN of a KMS CMK."
}

variable "logbucket" {
  type        = string
  description = "A name of an S3 Bucket for logs."
}

variable "session_dynamodb_region" {
  type        = string
  description = "A region of a DynamoDB Table for flask-dynamodb-sessions. See https://pypi.org/project/flask-dynamodb-sessions/"
}

variable "session_dynamodb_table" {
  type        = string
  description = "A name of a DynamoDB Table for flask-dynamodb-sessions. See https://pypi.org/project/flask-dynamodb-sessions/"
}

variable "apigw_id" {
  type        = string
  description = "An ID of the API Gateway."
}

variable "apigw_exec_arn" {
  type        = string
  description = "An ARN of the API Gateway Execution."
}

variable "apigw_route_http_method" {
  type        = string
  description = "A path for the API. Exmaple: GET"
}

variable "apigw_route_http_path" {
  type        = string
  description = "A path for the API. Exmaple: /healthz"
}

variable "lambda_handler" {
  type        = string
  description = "A Lambda handler. Example: index.healthz"
}

variable "lambda_runtime" {
  type        = string
  description = "A Lambda runtime. Example: python3.8"
}

variable "lambda_zip_file" {
  type        = string
  description = "A file name of the packaged Lambda. Example: index.zip"
}
