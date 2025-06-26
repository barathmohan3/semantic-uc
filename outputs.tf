output "s3_bucket" {
  value = aws_s3_bucket.documents.bucket
}

output "db_endpoint" {
  value = aws_db_instance.pgvector.address
}

output "api_endpoint" {
  value = aws_apigatewayv2_api.search_api.api_endpoint
}
