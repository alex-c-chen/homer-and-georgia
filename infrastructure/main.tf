terraform {
  required_version = ">= 1.9"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      app = var.app_name
      env = var.env
    }
  }
}

locals {
  prefix = "${var.app_name}-${var.env}"
}

# ---------------------------------------------------------------------------
# Secrets Manager — keeps API keys out of env vars / source control
# ---------------------------------------------------------------------------

resource "aws_secretsmanager_secret" "neon_conn" {
  name                    = "${local.prefix}/neon-connection-string"
  recovery_window_in_days = 0 # allow immediate deletion in dev
}

resource "aws_secretsmanager_secret_version" "neon_conn" {
  secret_id     = aws_secretsmanager_secret.neon_conn.id
  secret_string = var.neon_connection_string
}

resource "aws_secretsmanager_secret" "anthropic_key" {
  name                    = "${local.prefix}/anthropic-api-key"
  recovery_window_in_days = 0
}

resource "aws_secretsmanager_secret_version" "anthropic_key" {
  secret_id     = aws_secretsmanager_secret.anthropic_key.id
  secret_string = var.anthropic_api_key
}

# ---------------------------------------------------------------------------
# S3 — question JSON blobs  (key pattern: questions/{schedule_id}/{question_id}.json)
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "questions" {
  bucket = "${local.prefix}-questions"
}

resource "aws_s3_bucket_public_access_block" "questions" {
  bucket                  = aws_s3_bucket.questions.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "questions" {
  bucket = aws_s3_bucket.questions.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# ---------------------------------------------------------------------------
# ECR — container image for the FastAPI app
# ---------------------------------------------------------------------------

resource "aws_ecr_repository" "api" {
  name                 = "${local.prefix}-api"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

# ---------------------------------------------------------------------------
# IAM — shared execution role for both Lambda functions
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_exec" {
  name               = "${local.prefix}-lambda-exec"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

resource "aws_iam_role_policy_attachment" "lambda_basic_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_perms" {
  # S3: read + write question blobs
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.questions.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.questions.arn]
  }
  # Secrets: read API keys at runtime
  statement {
    actions = ["secretsmanager:GetSecretValue"]
    resources = [
      aws_secretsmanager_secret.neon_conn.arn,
      aws_secretsmanager_secret.anthropic_key.arn,
    ]
  }
  # Cost Explorer: read-only, for /usage/summary endpoint
  statement {
    actions   = ["ce:GetCostAndUsage", "ce:GetCostForecast"]
    resources = ["*"] # Cost Explorer requires * resource
  }
}

resource "aws_iam_role_policy" "lambda_perms" {
  name   = "${local.prefix}-lambda-perms"
  role   = aws_iam_role.lambda_exec.id
  policy = data.aws_iam_policy_document.lambda_perms.json
}

# ---------------------------------------------------------------------------
# Lambda — FastAPI app (container image, streaming Function URL)
# Streaming is required for SSE chat responses to the iOS app.
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "api" {
  function_name = "${local.prefix}-api"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  image_uri     = "${aws_ecr_repository.api.repository_url}:latest"
  timeout       = 300 # SSE sessions can run for several minutes
  memory_size   = 512

  environment {
    variables = {
      NEON_SECRET_ARN     = aws_secretsmanager_secret.neon_conn.arn
      ANTHROPIC_SECRET_ARN = aws_secretsmanager_secret.anthropic_key.arn
      S3_BUCKET           = aws_s3_bucket.questions.bucket
      ENV                 = var.env
    }
  }
}

# Function URL with RESPONSE_STREAM enables SSE without API Gateway buffering
resource "aws_lambda_function_url" "api" {
  function_name      = aws_lambda_function.api.function_name
  authorization_type = "NONE" # Add Cognito/JWT auth before exposing publicly
  invoke_mode        = "RESPONSE_STREAM"

  cors {
    allow_origins = ["*"] # Tighten to your domain + iOS app bundle ID before prod
    allow_methods = ["GET", "POST", "PATCH", "DELETE", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
  }
}

# ---------------------------------------------------------------------------
# Lambda — nightly cron job (question generation via Anthropic Batch API)
# ---------------------------------------------------------------------------

resource "aws_lambda_function" "cron" {
  function_name = "${local.prefix}-cron"
  role          = aws_iam_role.lambda_exec.arn
  package_type  = "Image"
  # Reuse the same image; entrypoint overridden below
  image_uri    = "${aws_ecr_repository.api.repository_url}:latest"
  timeout      = 900 # 15 min max — batch submission is fast, polling may need a step function later
  memory_size  = 256

  image_config {
    command = ["cron.handler"] # Python handler: backend/cron.py::handler
  }

  environment {
    variables = {
      NEON_SECRET_ARN      = aws_secretsmanager_secret.neon_conn.arn
      ANTHROPIC_SECRET_ARN = aws_secretsmanager_secret.anthropic_key.arn
      S3_BUCKET            = aws_s3_bucket.questions.bucket
      ENV                  = var.env
    }
  }
}

# ---------------------------------------------------------------------------
# EventBridge Scheduler — fires cron Lambda at 2 AM Eastern (7 AM UTC)
# ---------------------------------------------------------------------------

data "aws_iam_policy_document" "scheduler_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["scheduler.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "scheduler" {
  name               = "${local.prefix}-scheduler"
  assume_role_policy = data.aws_iam_policy_document.scheduler_assume.json
}

resource "aws_iam_role_policy" "scheduler_invoke" {
  name = "${local.prefix}-scheduler-invoke"
  role = aws_iam_role.scheduler.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "lambda:InvokeFunction"
      Resource = aws_lambda_function.cron.arn
    }]
  })
}

resource "aws_scheduler_schedule" "nightly" {
  name       = "${local.prefix}-nightly-question-gen"
  group_name = "default"

  flexible_time_window {
    mode = "OFF" # exact time, no flex
  }

  schedule_expression          = var.cron_schedule_expression
  schedule_expression_timezone = "America/New_York"

  target {
    arn      = aws_lambda_function.cron.arn
    role_arn = aws_iam_role.scheduler.arn
  }
}
