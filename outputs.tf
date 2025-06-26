output "db_endpoint" {
  value = aws_db_instance.pgvector.address
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.search_api.api_endpoint
}
