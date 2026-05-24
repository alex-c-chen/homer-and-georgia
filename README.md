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
