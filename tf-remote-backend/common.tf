data "aws_caller_identity" "this" {}
locals {
  accountid = data.aws_caller_identity.this.account_id
  logbucket = "logbucket-${local.accountid}"
}
