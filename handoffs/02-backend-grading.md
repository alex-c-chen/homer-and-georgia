# Handoff 02 — Backend: LLM Grading + Auth

## Context

The backend is a FastAPI app at `backend/`. It's fully scaffolded but two key features
are missing: **answer grading** (the `chat_session.is_correct` field is always null)
and **authentication** (any caller can hit any endpoint).

Read `backend/models.py` and `backend/routers/chat.py` before starting.

---

## Task 1 — LLM answer grading

### What to build

After the user submits their initial answer (`role=user_initial_answer`), the backend
should call Claude to grade it and set `chat_session.is_correct`.

This should happen **synchronously inside `POST /chat/sessions`** — before the 201
response returns — so the iOS app can read `is_correct` from the session immediately.

### Where to add it

`backend/routers/chat.py` → `start_session()` function, after the two `ChatMessage`
rows are inserted.

### Implementation

```python
async def _grade_answer(
    prompt: str,
    answer_key: str,
    user_answer: str,
    model: str,
) -> bool:
    """Call Claude to grade a user answer against the answer key.

    :returns: True if substantially correct, False otherwise.
    """
    client = _get_anthropic_client()
    resp = client.messages.create(
        model=model,
        max_tokens=64,
        system=(
            "You are a strict but fair grader. "
            "Reply with exactly one word: CORRECT or INCORRECT."
        ),
        messages=[{
            "role": "user",
            "content": (
                f"Question: {prompt}\n\n"
                f"Answer key: {answer_key}\n\n"
                f"Student answer: {user_answer}\n\n"
                "Is the student answer substantially correct?"
            ),
        }],
    )
    text = resp.content[0].text.strip().upper()

    # Record usage
    return text.startswith("CORRECT")
```

Call `_grade_answer` after inserting the two messages, set `session.is_correct`, then
record an `LLMUsage` row for the grading call (operation="grading").

**Pricing for grading calls (tiny prompts):**
- Same rate as chat: $3/MTok input, $15/MTok output, 50% batch discount does NOT apply here.

### Also add: reveal endpoint

The iOS app needs to show the correct answer after the user submits. Add:

```
GET /schedule/questions/{question_id}/reveal
```

Returns `{ "answer_key": str, "explanation": str }`. Only callable if a `chat_session`
exists for this question (i.e., the user has already submitted an answer).

Location: `backend/routers/schedule.py`.

---

## Task 2 — Bearer token auth

### What to build

Add a static bearer token check to all non-health endpoints. The token is set via the
`API_SECRET` environment variable.

### Implementation

Add `backend/auth.py`:

```python
import os
from fastapi import Header, HTTPException

async def require_auth(authorization: str = Header(...)) -> None:
    """FastAPI dependency that validates the Bearer token.

    :raises HTTPException 401: if the token is missing or wrong.
    """
    secret = os.environ.get("API_SECRET")
    if not secret:
        return  # auth disabled in dev if env var not set
    if authorization != f"Bearer {secret}":
        raise HTTPException(401, "Unauthorized")
```

Apply it as a router-level dependency in `main.py`:

```python
from auth import require_auth

app.include_router(schedule.router, prefix="/schedule", dependencies=[Depends(require_auth)])
app.include_router(chat.router,     prefix="/chat",     dependencies=[Depends(require_auth)])
app.include_router(usage.router,    prefix="/usage",    dependencies=[Depends(require_auth)])
```

`GET /health` stays open (no auth).

### iOS side

Add `API_SECRET` to `Config.swift` (read from env var or hardcoded for now):

```swift
static let apiSecret = ProcessInfo.processInfo.environment["API_SECRET"] ?? ""
```

`APIClient` should set `Authorization: Bearer {apiSecret}` on every request.

---

## Task 3 — Structured logging

Replace `print()` calls in `cron.py` with structured JSON logging so Fly.io log drains
(and GitHub Actions) can parse them.

```python
import logging, json

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger(__name__)

# Usage:
log.info(json.dumps({"event": "batch_submitted", "batch_id": batch.id, "request_count": len(requests)}))
log.info(json.dumps({"event": "batch_complete", "total_input_tokens": total_input, "cost_cents": float(cost)}))
```

Apply the same pattern to `main.py` (startup log) and `routers/chat.py` (log each SSE session open/close).

---

## Conventions

- Sphinx docstrings, terse inline comments only
- Run `uv run ruff check --fix . && uv run ruff format .` before committing
- `uv run ty check .` (advisory)
- Add `API_SECRET` to `backend/.env.example`

---

## Verification

```bash
# Grading
curl -s -X POST http://localhost:8080/chat/sessions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_SECRET" \
  -d '{"question_id": "<uuid>", "initial_answer": "some answer"}' \
  | jq '.is_correct'
# should return true or false (not null)

# Auth
curl -s http://localhost:8080/schedule/today
# should return 401 when API_SECRET is set

curl -s http://localhost:8080/health
# should return {"status":"ok"} with no auth

# Reveal
curl -s http://localhost:8080/schedule/questions/<uuid>/reveal \
  -H "Authorization: Bearer $API_SECRET"
# should return {"answer_key":"...","explanation":"..."}
```
