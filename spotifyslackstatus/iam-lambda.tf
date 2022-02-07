locals {
  role_lambda_name   = "${local.app}-lambda-role"
  policy_lambda_name = "${local.app}-logging-policy"
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
      {
        "Effect" : "Deny",
        "Action" : "logs:CreateLogGroup",
        "Resource" : "*"
      },
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
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_lambda" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = aws_iam_policy.policy_lambda.arn
}
resource "aws_iam_role_policy_attachment" "attach_role_policy_lambdainsights" {
  role       = aws_iam_role.role_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchLambdaInsightsExecutionRolePolicy"
}
