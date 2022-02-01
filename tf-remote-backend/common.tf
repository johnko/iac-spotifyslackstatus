data "aws_caller_identity" "this" {}
locals {
  region    = "ca-central-1"
  accountid = data.aws_caller_identity.this.account_id
  logbucket = "logbucket-${local.accountid}"
}
