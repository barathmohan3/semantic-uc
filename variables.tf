# === terraform/variables.tf ===
variable "aws_region" {
  default = "us-east-1"
}

variable "bucket_name" {
  default = "semantic-docs-bucket"
}

variable "db_user" {
  default = "admin"
}

variable "db_password" {
  default = "StrongPassword123"
}

variable "openai_api_key" {
  description = "Your OpenAI API Key"
}

