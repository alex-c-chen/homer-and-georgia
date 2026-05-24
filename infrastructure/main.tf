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
# S3 — question JSON blobs  (key: questions/{schedule_id}/{question_id}.json)
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
# IAM — service user for GitHub Actions cron + Fly.io app
# Credentials go into GitHub Secrets and Fly.io secrets respectively.
# ---------------------------------------------------------------------------

resource "aws_iam_user" "app" {
  name = "${local.prefix}-app"
}

resource "aws_iam_access_key" "app" {
  user = aws_iam_user.app.name
}

data "aws_iam_policy_document" "app_perms" {
  statement {
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.questions.arn}/*"]
  }
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.questions.arn]
  }
  statement {
    actions   = ["ce:GetCostAndUsage", "ce:GetCostForecast"]
    resources = ["*"]
  }
}

resource "aws_iam_user_policy" "app_perms" {
  name   = "${local.prefix}-app-perms"
  user   = aws_iam_user.app.name
  policy = data.aws_iam_policy_document.app_perms.json
}
