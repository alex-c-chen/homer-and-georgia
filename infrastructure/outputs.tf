output "api_url" {
  description = "Lambda Function URL for the FastAPI app (iOS + browser)"
  value       = aws_lambda_function_url.api.function_url
}

output "ecr_repository_url" {
  description = "ECR URL — tag your image here before deploying"
  value       = aws_ecr_repository.api.repository_url
}

output "questions_bucket" {
  description = "S3 bucket name for question JSON blobs"
  value       = aws_s3_bucket.questions.bucket
}

output "neon_secret_arn" {
  description = "Secrets Manager ARN for the Neon connection string"
  value       = aws_secretsmanager_secret.neon_conn.arn
}
