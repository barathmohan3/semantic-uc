# === main.tf ===
provider "aws" {
  region = var.aws_region
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "documents" {
  bucket = var.bucket_name
}

resource "aws_iam_role" "lambda_exec" {
  name = "lambda_exec_role_${random_id.suffix.hex}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "null_resource" "zip_parser" {
  provisioner "local-exec" {
    command = "zip -j lambda/parser_lambda.zip lambda/parser_lambda.py"
  }
}

data "archive_file" "parser_lambda" {
  type        = "zip"
  source_file = "lambda/parser_lambda.py"
  output_path = "lambda/parser_lambda.zip"
  depends_on  = [null_resource.zip_parser]
}

resource "null_resource" "zip_search" {
  provisioner "local-exec" {
    command = "zip -j lambda/search_lambda.zip lambda/search_lambda.py"
  }
}

data "archive_file" "search_lambda" {
  type        = "zip"
  source_file = "lambda/search_lambda.py"
  output_path = "lambda/search_lambda.zip"
  depends_on  = [null_resource.zip_search]
}

resource "aws_lambda_function" "parser" {
  filename         = data.archive_file.parser_lambda.output_path
  function_name    = "parserLambda"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "parser_lambda.lambda_handler"
  runtime          = "python3.9"
  layers = [aws_lambda_layer_version.semantic_layer.arn]
  source_code_hash = data.archive_file.parser_lambda.output_base64sha256
  environment {
    variables = {
      DB_HOST        = aws_db_instance.pgvector.address
      DB_USER        = var.db_user
      DB_PASSWORD    = var.db_password
      OPENAI_API_KEY = var.openai_api_key
    }
  }
}

resource "aws_lambda_function" "search" {
  filename         = data.archive_file.search_lambda.output_path
  function_name    = "searchLambda"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "search_lambda.lambda_handler"
  runtime          = "python3.9"
  layers = [aws_lambda_layer_version.semantic_layer.arn]
  source_code_hash = data.archive_file.search_lambda.output_base64sha256
  environment {
    variables = {
      DB_HOST        = aws_db_instance.pgvector.address
      DB_USER        = var.db_user
      DB_PASSWORD    = var.db_password
      OPENAI_API_KEY = var.openai_api_key
    }
  }
}

resource "aws_lambda_layer_version" "semantic_layer" {
  layer_name          = "semantic-layer"
  description         = "Layer with psycopg2, openai, boto3, PyPDF2"
  compatible_runtimes = ["python3.9"]

  s3_bucket = "semantic-docs-bucket"
  s3_key    = "layers/layer.zip"
}

resource "aws_db_instance" "pgvector" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "14.16"
  instance_class       = "db.t3.micro"
  db_name              = "vectorsearch"
  username             = var.db_user
  password             = var.db_password
  skip_final_snapshot  = true
  publicly_accessible  = true
}

resource "aws_apigatewayv2_api" "search_api" {
  name          = "semantic-search-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id                  = aws_apigatewayv2_api.search_api.id
  integration_type        = "AWS_PROXY"
  integration_uri         = aws_lambda_function.search.invoke_arn
  integration_method      = "POST"
  payload_format_version  = "2.0"
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.search_api.id
  route_key = "POST /search"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.search_api.id
  name        = "$default"
  auto_deploy = true
}
