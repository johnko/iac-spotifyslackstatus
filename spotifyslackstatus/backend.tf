terraform {
  backend "s3" {
    key = "spotifyslackstatus/terraform.tfstate"

    kms_key_id     = "arn:aws:kms:ca-central-1:AWS_ACCOUNT_ID:alias/aws/s3"
    dynamodb_table = "statelock-AWS_ACCOUNT_ID"
    bucket         = "statebucket-AWS_ACCOUNT_ID"

    encrypt = true
    region  = "ca-central-1"
  }
}
