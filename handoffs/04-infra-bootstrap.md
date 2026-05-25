# Handoff 04 — Infrastructure Bootstrap & First Deploy

## Context

All infrastructure code is written. This handoff executes it end-to-end:
Terraform → AWS, Neon setup, Fly.io deploy, GitHub secrets, smoke test.

Read `infrastructure/README.md` and `backend/README.md` before starting.

---

## Prerequisites (human must supply)

The following accounts and credentials must exist before running this handoff:

- [ ] AWS account with IAM admin access (`aws configure` working locally)
- [ ] Neon account — project created, connection string copied
- [ ] Fly.io account — `fly auth login` completed
- [ ] GitHub repo at `alex-c-chen/homer-and-georgia` — secrets can be set via `gh` CLI
- [ ] Anthropic API key

---

## Step 1 — Terraform (AWS)

```bash
cd infrastructure

# Create prod tfvars (gitignored)
cat > prod.tfvars <<EOF
env     = "prod"
EOF

terraform init
terraform plan -var-file=prod.tfvars
terraform apply -var-file=prod.tfvars   # type "yes"

# Capture outputs
AWS_ACCESS_KEY_ID=$(terraform output -raw aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(terraform output -raw aws_secret_access_key)
S3_BUCKET=$(terraform output -raw questions_bucket)

echo "S3_BUCKET: $S3_BUCKET"
echo "Save the key ID and secret — they won't be shown again."
```

**Expected resources created:**
- `homer-and-georgia-prod-questions` S3 bucket (private, AES256 encrypted)
- `homer-and-georgia-prod-app` IAM user with S3 + Cost Explorer permissions

---

## Step 2 — GitHub Actions secrets

```bash
# Requires gh CLI (brew install gh)
gh secret set DATABASE_URL         --body "$NEON_CONNECTION_STRING"
gh secret set ANTHROPIC_API_KEY    --body "$ANTHROPIC_API_KEY"
gh secret set S3_BUCKET            --body "$S3_BUCKET"
gh secret set AWS_ACCESS_KEY_ID    --body "$AWS_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "$AWS_SECRET_ACCESS_KEY"
gh secret set API_SECRET           --body "$(openssl rand -hex 32)"
```

Verify in GitHub → Settings → Secrets and variables → Actions.

---

## Step 3 — Neon: run migrations

```bash
cd backend
DATABASE_URL="$NEON_CONNECTION_STRING" uv run alembic upgrade head
DATABASE_URL="$NEON_CONNECTION_STRING" uv run python seed.py
```

Expected:
```
INFO  [alembic.runtime.migration] Running upgrade  -> <hash>, initial schema
Seeded 5 topic types, 3 question types.
```

Once topics are seeded (handoff 03), run `seed.py` again to add topic rows.

---

## Step 4 — Fly.io: first deploy

```bash
cd backend
fly launch --no-deploy --name homer-and-georgia

# Set secrets (Fly stores these as encrypted env vars)
fly secrets set \
    DATABASE_URL="$NEON_CONNECTION_STRING" \
    ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
    S3_BUCKET="$S3_BUCKET" \
    AWS_ACCESS_KEY_ID="$AWS_ACCESS_KEY_ID" \
    AWS_SECRET_ACCESS_KEY="$AWS_SECRET_ACCESS_KEY" \
    API_SECRET="$(gh secret list | grep API_SECRET)"
    # ↑ or paste the same value used for GitHub

fly deploy
```

**Expected output:** `✓ Machine … completed successfully` and a `.fly.dev` URL.

```bash
# Smoke test
API_URL=$(fly status --json | jq -r '.Hostname')
curl -s "https://$API_URL/health"
# {"status":"ok"}

curl -s "https://$API_URL/schedule/today" \
  -H "Authorization: Bearer $API_SECRET"
# {"detail":"No schedule for today — cron may not have run yet."} — expected
```

---

## Step 5 — Test the cron manually

Trigger a manual run to verify the full pipeline before waiting for 2 AM:

```bash
gh workflow run nightly-questions.yml
gh run watch   # tail the run live
```

Expected sequence in the logs:
```
Submitted batch msg_batch_xxx with 21 requests.
  [10s] status=in_progress
  ...
  [120s] status=ended
Done — 21 questions ready for 2026-05-26.
```

Then verify data was written:

```bash
# Check S3
aws s3 ls s3://$S3_BUCKET/questions/ --recursive | head

# Check Neon
DATABASE_URL="$NEON_CONNECTION_STRING" uv run python - <<'EOF'
from db import SessionLocal
from models import DailySchedule, Question
db = SessionLocal()
sched = db.query(DailySchedule).order_by(DailySchedule.date.desc()).first()
print("Latest schedule:", sched.date, sched.status)
print("Question count:", db.query(Question).filter(Question.daily_schedule_id == sched.id).count())
EOF
```

---

## Step 6 — Update iOS Config

Once the Fly.io URL is confirmed:

```bash
FLY_URL="https://homer-and-georgia.fly.dev"
```

Update `ios/HomerAndGeorgia/Config/Config.swift`:

```swift
static let apiBaseURL = URL(string: "https://homer-and-georgia.fly.dev")!
static let apiSecret  = "..."   // same value as API_SECRET secret
```

---

## Rollback / teardown

```bash
# Fly.io
fly apps destroy homer-and-georgia

# Terraform
cd infrastructure
terraform destroy -var-file=prod.tfvars   # destroys S3 + IAM user
# WARNING: this deletes all question blobs in S3
```

---

## Ongoing operations

| Task | Command |
|---|---|
| Deploy backend update | `fly deploy` (from `backend/`) |
| Tail live logs | `fly logs` |
| SSH into machine | `fly ssh console` |
| Run migrations on prod | `fly ssh console` → `uv run alembic upgrade head` |
| Trigger cron manually | `gh workflow run nightly-questions.yml` |
| Rotate API secret | `fly secrets set API_SECRET="..."` + update GitHub secret |
