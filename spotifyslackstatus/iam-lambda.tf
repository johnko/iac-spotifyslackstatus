locals {
  role_lambda_name           = "${local.app}-lambda-role"
  policy_lambda_name         = "${local.app}-logging-policy"
  policy_getparameter_name   = "${local.app}-getparameter-policy"
  policy_updatedynamodb_name = "${local.app}-updatedynamodb-policy"
}

####################
##### IAM for Lambda
resource "aws_iam_role" "role_lambda" {
  name = local.role_lambda_name
  assume_role_policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowLambdaServiceAssumeRole",
        "Action" : "sts:AssumeRole",
        "Effect" : "Allow",
        "Principal" : {
          "Service" : "lambda.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name               = local.role_lambda_name
    dataclassification = "internal"
  }
}
resource "aws_iam_policy" "policy_lambda" {
  name        = local.policy_lambda_name
  path        = "/"
  description = "Let Lambda write logs to Cloudwatch"
  # Don't allow logs:CreateLogGroup because we create the encrypted loggroup_lambda
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      # {
      #   "Effect" : "Deny",
      #   "Action" : "logs:CreateLogGroup",
      #   "Resource" : "*"
      # },
      {
        "Sid" : "AllowLambdaCreateLogs",
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:logs:*:${local.accountid}:*"
      }
    ]
  })
  tags = {
    Name               = local.policy_lambda_name
    dataclassification = "internal"
  }
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_lambda" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = aws_iam_policy.policy_lambda.arn
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_lambdainsights" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}

##### Lambda ssm:GetParameter
resource "aws_iam_policy" "policy_getparameter" {
  name        = local.policy_getparameter_name
  path        = "/"
  description = "Let Lambda get SSM Parameter value"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowSSMGetParameter",
        "Action" : [
          "ssm:GetParameter"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:ssm:*:${local.accountid}:parameter/*"
      },
      {
        "Sid" : "AllowDecryptSSMParameter",
        "Action" : [
          "kms:Decrypt"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_kms_key.cmk_spotifyslackstatus.arn}"
      }
    ]
  })
  tags = {
    Name               = local.policy_getparameter_name
    dataclassification = "internal"
  }
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_lambda_getparameter" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = aws_iam_policy.policy_getparameter.arn
}

##### Lambda dynamodb:
resource "aws_iam_policy" "policy_updatedynamodb" {
  name        = local.policy_updatedynamodb_name
  path        = "/"
  description = "Let Lambda get SSM Parameter value"
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowSSMGetParameter",
        "Action" : [
          "dynamodb:DeleteItem",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_dynamodb_table.sessiontable.arn}"
      },
      {
        "Sid" : "AllowDecryptSSMParameter",
        "Action" : [
          "kms:Decrypt"
        ],
        "Effect" : "Allow",
        "Resource" : "${aws_kms_key.cmk_spotifyslackstatus.arn}"
      }
    ]
  })
  tags = {
    Name               = local.policy_updatedynamodb_name
    dataclassification = "internal"
  }
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_lambda_updatedynamodb" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = aws_iam_policy.policy_updatedynamodb.arn
}
