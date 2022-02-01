locals {
  sessiontable    = "spotifyslackstatus-flask_sessions-${local.accountid}"
  lambdafunc      = "spotifyslackstatus-lambda-func"
  lambdarole      = "spotifyslackstatus-lambda-role"
  lambdalogpolicy = "spotifyslackstatus-lambda-log-policy"
}

##### StateLock DynamoDB
resource "aws_dynamodb_table" "statelock_table" {
  name         = local.sessiontable
  billing_mode = "PAY_PER_REQUEST"
  # https://pypi.org/project/flask-dynamodb-sessions/
  # aws dynamodb create-table --key-schema "AttributeName=id,KeyType=HASH" \
  # --attribute-definitions "AttributeName=id,AttributeType=S" \
  # --provisioned-throughput "ReadCapacityUnits=5,WriteCapacityUnits=5" \
  # --table-name flask_sessions
  hash_key = "id"
  attribute {
    name = "id"
    type = "S"
  }
  # aws dynamodb update-time-to-live --time-to-live-specification 'Enabled=true,AttributeName=ttl' --table-name flask_sessions
  ttl {
    enabled        = true
    attribute_name = "ttl"
  }
  server_side_encryption {
    enabled = true
  }
  table_class = "STANDARD"
  tags = {
    Name               = local.sessiontable
    dataclassification = "restricted"
  }
}

##### Lambda IAM Role
resource "aws_iam_role" "lambda_role" {
  name = local.lambdarole

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowLambdaServiceAssumeRole",
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
  tags = {
    Name               = local.lambdarole
    dataclassification = "internal"
  }
}

##### Lambda Managed IAM policy
resource "aws_iam_policy" "lambda_logging_policy" {
  name        = local.lambdalogpolicy
  path        = "/"
  description = "IAM policy for logging from a lambda"

  policy = <<EOF
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
      "Resource": "arn:aws:logs:*:*:*",
      "Effect": "Allow"
    }
  ]
}
EOF
}

##### Attach  Lambda Managed IAM policy  to  Lambda IAM Role
resource "aws_iam_role_policy_attachment" "lambda_attach_logging_policy" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_logging_policy.arn
}

##### Lambda Log Group
resource "aws_cloudwatch_log_group" "lambda_loggroup" {
  name              = "/aws/lambda/${local.lambdafunc}"
  retention_in_days = 90
}

##### Lambda
resource "aws_lambda_function" "lambda" {
  function_name = local.lambdafunc
  role          = aws_iam_role.lambda_role.arn

  handler  = "index.lambda_handler"
  filename = "lambda_function_payload.zip"
  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("lambda_function_payload.zip")

  runtime = "python3.8"

  environment {
    variables = {
      SESSION_DYNAMODB_TABLE  = local.sessiontable,
      SESSION_DYNAMODB_REGION = "ca-central-1",
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
