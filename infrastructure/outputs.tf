output "questions_bucket" {
  value = aws_s3_bucket.questions.bucket
}

output "aws_access_key_id" {
  value     = aws_iam_access_key.app.id
  sensitive = true
}

output "aws_secret_access_key" {
  value     = aws_iam_access_key.app.secret
  sensitive = true
}
