data "aws_region" "this" {}
data "aws_caller_identity" "this" {}
locals {
  region    = data.aws_region.this.name
  accountid = data.aws_caller_identity.this.account_id
  whoamiarn = data.aws_caller_identity.this.arn
  logbucket = "logbucket-${local.accountid}"
}
