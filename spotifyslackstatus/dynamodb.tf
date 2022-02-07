locals {
  sessiontable_name = "${local.app}-flask_sessions-${local.accountid}"
}

####################
##### StateLock DynamoDB
resource "aws_dynamodb_table" "sessiontable" {
  name         = local.sessiontable_name
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
    enabled     = true
    kms_key_arn = aws_kms_key.cmk_spotifyslackstatus.arn # comment this out if you want to use alias/aws/dynamodb
  }
  table_class = "STANDARD"
  tags = {
    Name               = local.sessiontable_name
    dataclassification = "restricted"
  }
}
