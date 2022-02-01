terraform {
  backend "s3" {
    key = "tf-remote-backend/terraform.tfstate"

    kms_key_id     = "arn:aws:kms:ca-central-1:341506437258:alias/aws/s3"
    dynamodb_table = "statelock-341506437258"
    bucket         = "statebucket-341506437258"

    encrypt = true
    region  = "ca-central-1"
  }
}
