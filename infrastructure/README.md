# Infrastructure

Terraform configuration for AWS resources. Intentionally minimal — hosting (Fly.io) and scheduling (GitHub Actions) live outside Terraform.

## Resources

| Resource | Purpose |
|---|---|
| `aws_s3_bucket.questions` | Question JSON blobs (`questions/{schedule_id}/{question_id}.json`) |
| `aws_iam_user.app` | Service account used by Fly.io + GitHub Actions |
| `aws_iam_access_key.app` | Access key — output via `terraform output` |
| `aws_iam_user_policy.app_perms` | S3 read/write + `ce:GetCostAndUsage` |

## First-time setup

```bash
cd infrastructure
terraform init
terraform plan -var="env=prod"
terraform apply -var="env=prod"

# Get IAM credentials
terraform output -raw aws_access_key_id
terraform output -raw aws_secret_access_key
```

Add those credentials to:
- **GitHub Secrets** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`) — used by the nightly cron
- **Fly.io secrets** — used by the FastAPI app at runtime

## State

Terraform state is local by default. For a team setup, move it to S3 + DynamoDB locking. For a solo project, committing the state file (with `.tfvars` gitignored) is acceptable.

## Variables

| Variable | Default | Description |
|---|---|---|
| `aws_region` | `us-east-1` | AWS region |
| `app_name` | `homer-and-georgia` | Resource name prefix |
| `env` | `dev` | Appended to resource names |

## What's intentionally NOT here

- **Fly.io** — managed via `fly.toml` + `fly` CLI, not Terraform
- **Neon** — managed via Neon console / Neon CLI
- **GitHub Actions** — defined in `.github/workflows/`
- **Lambda / ECS / EventBridge** — not used; Fly.io + GitHub Actions replace them
