locals {
  statelocktable_name = "statelock-${local.accountid}"
}

####################
##### StateLock DynamoDB
resource "aws_dynamodb_table" "table_statelock" {
  name         = local.statelocktable_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.cmk_tfremotebackend.arn # comment this out if you want to use alias/aws/dynamodb
  }
  table_class = "STANDARD"
  tags = {
    Name               = local.statelocktable_name
    dataclassification = "confidential"
  }
}
