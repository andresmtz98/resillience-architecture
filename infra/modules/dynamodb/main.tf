resource "aws_dynamodb_table" "state" {
  name         = local.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }
}

resource "aws_dynamodb_table_item" "initial_state" {
  table_name = aws_dynamodb_table.state.name
  hash_key   = aws_dynamodb_table.state.hash_key

  item = jsonencode({
    id                          = { S = "system" }
    level                       = { N = "1" }
    error_count_current_minute  = { N = "0" }
    current_minute_start        = { N = "0" }
    errors_last_minute          = { N = "0" }
    last_transition_at          = { N = "0" }
    last_transition_reason      = { S = "init" }
  })

  lifecycle {
    ignore_changes = [item]
  }
}
