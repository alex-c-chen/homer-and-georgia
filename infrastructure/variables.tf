variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "app_name" {
  description = "Base name used for all resource identifiers"
  type        = string
  default     = "homer-and-georgia"
}

variable "env" {
  description = "Deployment environment (dev | prod)"
  type        = string
  default     = "dev"
}

variable "neon_connection_string" {
  description = "Neon PostgreSQL connection string (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "anthropic_api_key" {
  description = "Anthropic API key (stored in Secrets Manager)"
  type        = string
  sensitive   = true
}

variable "cron_schedule_expression" {
  description = "EventBridge cron for nightly question generation — 2 AM Eastern = 7 AM UTC"
  type        = string
  default     = "cron(0 7 * * ? *)"
}
