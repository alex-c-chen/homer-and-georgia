# Homer & Georgia

A daily "keep sharp" iOS app. Asks questions across 5–10 topics per day — general knowledge plus math prep for the UT Austin MSDS Quest entrance exam. Questions are generated nightly by Claude, stored as JSON in S3, and served via a FastAPI backend on Fly.io.

See `mockup.html` for screen designs and `architecture.html` for the full system diagram.

## Repository layout

```
.
├── backend/          FastAPI app + cron worker + Alembic migrations
├── infrastructure/   Terraform (AWS S3 + IAM)
├── ios/              Swift/SwiftUI iOS app (source files)
├── CLAUDE.md         Code conventions, ID encoding schemes, key commands
├── TODO.md           Prioritised task list by vertical
├── mockup.html       6-screen iOS UI mockup
└── architecture.html System architecture diagram
```

## How it works

1. **2 AM Eastern** — GitHub Actions runs `cron.py`, which submits an Anthropic Batch API request to generate 3 questions per topic (21 questions total for 7 topics). Results are written to S3 and Neon.
2. **8:30 AM** — You open the app. Topics and questions are loaded from the FastAPI backend.
3. **Answer a question** — Your answer seeds a chat session. The LLM grades it and you can ask follow-ups via SSE streaming.
4. **Usage tab** — See month-to-date spend across LLM APIs and AWS.

## Quick start

See each vertical's README for detailed setup:

- [`backend/README.md`](backend/README.md) — local dev, migrations, Fly.io deploy
- [`infrastructure/README.md`](infrastructure/README.md) — Terraform setup, IAM credentials
- [`ios/README.md`](ios/README.md) — Xcode project setup, screen list

```bash
# 1. Provision AWS
cd infrastructure && terraform apply

# 2. Bootstrap backend
cd backend
cp .env.example .env   # fill in credentials
uv sync --dev
uv run alembic upgrade head
uv run python seed.py

# 3. Run locally
uv run uvicorn main:app --reload --port 8080

# 4. Deploy
fly deploy
```

## Deployment

The backend, database, blob storage, and nightly cron are already provisioned. This
section is the full runbook for redeploying or standing the system up from scratch.

### 1. Secrets

The same five credentials are needed in **three** places. Forgetting `ANTHROPIC_API_KEY`
is the classic mistake — without it, chat + grading 500 in prod and the nightly cron
generates nothing.

| Secret | Fly (runtime) | GitHub Actions (cron) | iOS app |
|---|:---:|:---:|:---:|
| `DATABASE_URL` | ✓ | ✓ | — |
| `ANTHROPIC_API_KEY` | ✓ | ✓ | — |
| `S3_BUCKET` | ✓ | ✓ | — |
| `AWS_ACCESS_KEY_ID` | ✓ | ✓ | — |
| `AWS_SECRET_ACCESS_KEY` | ✓ | ✓ | — |
| `API_SECRET` | ✓ | — | ✓ (must match Fly) |

```bash
# Fly (used by the running FastAPI app)
fly secrets set ANTHROPIC_API_KEY="sk-ant-..." DATABASE_URL="..." \
    S3_BUCKET="..." AWS_ACCESS_KEY_ID="..." AWS_SECRET_ACCESS_KEY="..." \
    API_SECRET="..." -a homer-and-georgia

# GitHub Actions (used by the nightly question generator)
gh secret set ANTHROPIC_API_KEY --body "sk-ant-..."
gh secret set DATABASE_URL --body "..."
gh secret set S3_BUCKET --body "..."
gh secret set AWS_ACCESS_KEY_ID --body "..."
gh secret set AWS_SECRET_ACCESS_KEY --body "..."

# Verify
fly secrets list -a homer-and-georgia
gh secret list
```

### 2. Backend (Fly.io)

```bash
cd backend
fly deploy                       # build Dockerfile + roll machines
curl https://homer-and-georgia.fly.dev/health   # expect {"status":"ok"}
```

`fly.toml` has **no** `release_command`, so migrations are not automatic. After any
schema change, run them explicitly before/after deploy:

```bash
fly ssh console -a homer-and-georgia -C "uv run alembic upgrade head"
```

Note: `fly secrets set` also triggers a rolling restart, so a secret change alone
redeploys the current image without a separate `fly deploy`.

### 3. Nightly cron (GitHub Actions)

Defined in `.github/workflows/nightly-questions.yml` — runs at 07:00 UTC. Trigger a
manual run to test generation end-to-end:

```bash
gh workflow run "Nightly question generation"
gh run watch
```

### 4. iOS app → your iPhone

The app reads its backend URL and token from `API_BASE_URL` / `API_SECRET`. The
`ios/project.yml` scheme sets these for **local dev** (`localhost:8080`, empty token).
For a device build you must point at prod and supply the real `API_SECRET` — otherwise
the phone tries its own `localhost` and prod returns 401.

**Path A — quick, free (re-sign every 7 days):**

1. Open the project: `cd ios && xcodegen && open HomerAndGeorgia.xcodeproj`
2. Edit Scheme → Run → Arguments → Environment Variables:
   - `API_BASE_URL = https://homer-and-georgia.fly.dev`
   - `API_SECRET   = <the Fly API_SECRET value>`
3. Signing & Capabilities → set Team to your personal Apple ID.
4. Select your connected iPhone as the destination and Run.

A free Apple ID provisioning profile lasts **7 days**; re-running from Xcode resets the
clock. The app stops launching once a profile lapses until you redeploy. This is
perpetually renewable but Mac- and Xcode-tethered.

**Path B — persistent (Apple Developer Program, $99/yr):**

Scheme environment variables do **not** apply to Release/Archive builds, so bake the
config into the bundle (a gitignored `.xcconfig` feeding Info.plist keys, read via
`Bundle.main` in `Config.swift`) before archiving. Then **Product → Archive → Distribute
→ TestFlight** and install via the TestFlight app — no weekly re-signing.

## Tech stack

| Layer | Technology |
|---|---|
| iOS | SwiftUI, URLSession (SSE), iOS 17+ |
| API | FastAPI, SQLAlchemy, Alembic, Python 3.15, uv |
| Database | Neon (serverless PostgreSQL) |
| Blob storage | AWS S3 |
| LLM | Anthropic Claude (Batch + Streaming) |
| Hosting | Fly.io (auto-stop, ~$0–3/month) |
| Cron | GitHub Actions (`schedule:` trigger) |
| Infrastructure | Terraform (S3 + IAM only) |
