output "table_name" {
  value = aws_dynamodb_table.state.name
}

output "table_arn" {
  value = aws_dynamodb_table.state.arn
}
