locals {
  spotifyslackstatustable = "spotifyslackstatus-flask_sessions-${local.accountid}"
}

##### StateLock DynamoDB
resource "aws_dynamodb_table" "statelock_table" {
  name         = local.spotifyslackstatustable
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
    Name               = local.spotifyslackstatustable
    dataclassification = "restricted"
  }
}
