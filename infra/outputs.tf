output "api_gateway_url" {
  description = "POST endpoint for service-api"
  value       = module.api_gateway.invoke_url
}

output "state_table_name" {
  value = module.dynamodb.table_name
}
