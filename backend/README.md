# Backend

FastAPI application serving the Homer & Georgia iOS app. Handles schedule retrieval, SSE chat streaming, question content proxying, and the cost-usage dashboard.

## Architecture

```
main.py
├── GET  /health
├── /schedule  →  routers/schedule.py
│   ├── GET /today
│   ├── GET /{id}/topics
│   ├── GET /{id}/questions
│   └── GET /questions/{question_id}   ← proxies S3 blob to iOS
├── /chat  →  routers/chat.py
│   ├── POST /sessions                 ← seeds initial answer + opens thread
│   ├── POST /sessions/{id}/messages   ← SSE stream (text/event-stream)
│   └── GET  /sessions/{id}/messages
└── /usage  →  routers/usage.py
    └── GET /summary                   ← Neon LLM rows + AWS Cost Explorer
```

**Question content flow** — S3 credentials never reach the iOS device:
```
iOS → GET /schedule/questions/{id} → FastAPI → S3 blob → JSON
```

**Chat/SSE flow:**
```
iOS → POST /chat/sessions/{id}/messages
    ← text/event-stream  {event: delta, data: {"delta": "…"}}
                         {event: done,  data: "[DONE]"}
FastAPI streams from Anthropic, writes LLMUsage row on close.
```

## Local development

```bash
cp .env.example .env          # fill in DATABASE_URL, ANTHROPIC_API_KEY, S3_BUCKET, AWS_*
uv sync --dev
uv run alembic upgrade head
uv run python seed.py         # idempotent — seeds TopicType + QuestionType rows
uv run uvicorn main:app --reload --port 8080
# Swagger UI at http://localhost:8080/docs
```

## Migrations

```bash
uv run alembic revision --autogenerate -m "describe change"
uv run alembic upgrade head
uv run alembic downgrade -1   # roll back one step
```

## Deploy (Fly.io)

```bash
# First time
fly launch --no-deploy
fly secrets set \
    DATABASE_URL="..." \
    ANTHROPIC_API_KEY="..." \
    S3_BUCKET="..." \
    AWS_ACCESS_KEY_ID="..." \
    AWS_SECRET_ACCESS_KEY="..."
fly deploy

# Debug
fly logs
fly ssh console
```

## Lint / type check

```bash
uv run ruff check . && uv run ruff format .
uv run ty check .   # alpha — advisory
```

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `DATABASE_URL` | ✓ | Neon PostgreSQL connection string |
| `ANTHROPIC_API_KEY` | ✓ | Anthropic API key |
| `S3_BUCKET` | ✓ | S3 bucket for question blobs |
| `AWS_ACCESS_KEY_ID` | ✓ | IAM user from Terraform output |
| `AWS_SECRET_ACCESS_KEY` | ✓ | IAM user secret |
| `API_SECRET` | — | Bearer token for `/schedule`, `/chat`, `/usage`. Unset = auth disabled (dev) |
| `ANTHROPIC_MODEL` | — | Default: `claude-sonnet-4-6` |
| `TOPICS_PER_DAY` | — | Default: `7` (used by cron) |
