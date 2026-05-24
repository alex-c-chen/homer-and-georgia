# homer-and-georgia

Daily "keep sharp" iOS app. Asks questions across 5–10 topics per day (general knowledge + math prep for UT Austin MSDS Quest exam). Questions are generated nightly via LLM batch API and stored as JSON blobs in S3; metadata lives in Neon (PostgreSQL).

## Stack

| Layer | Technology |
|---|---|
| API | FastAPI (Python 3.15, uv) |
| Database | Neon (PostgreSQL) via SQLAlchemy + Alembic |
| Blob storage | S3 — question JSON at `questions/{schedule_id}/{question_id}.json` |
| LLM | Anthropic (batch generation, chat, grading) |
| Hosting | TBD — Fly.io preferred over Lambda (easier SSE streaming + debugging) |
| Cron | TBD — GitHub Actions `schedule:` preferred over Lambda |

## Code conventions

- **Docstrings**: Sphinx style only. One-line summary for obvious classes; `:param:` / `:returns:` / `:raises:` only when non-obvious.
- **Comments**: only for non-obvious WHY (hidden constraint, workaround, subtle invariant). Never restate what the code does.
- **Lint/type**: `uv run ruff check . && uv run ruff format .` — `uv run ty check .` (alpha, advisory).

## Topic type ID convention

`topic_type.id` encodes category and sub-type as a 4-digit integer:

```
Thousands digit = category
  1xxx  Persons & Organizations
  2xxx  Historical Events
  3xxx  Geography
  4xxx  Arts
  5xxx  Science
  6xxx  Mathematics

For 1xxx / 2xxx / 3xxx: hundreds+tens+ones = ISO 3166-1 numeric country code
  1840  American person/org     (US = 840)
  1276  German person/org       (DE = 276)
  1392  Japanese person/org     (JP = 392)
  1000  International / stateless / ancient

For 4xxx: sub-category in hundreds digit
  41xx  Visual Arts
  42xx  Music
  43xx  Dance & Performing Arts
  44xx  Literature
  45xx  Film & Media

For 5xxx: sub-category in hundreds digit
  51xx  Physics
  52xx  Chemistry
  53xx  Biology
  54xx  Earth & Space Science

For 6xxx: math curriculum (sequential)
  6100  Calculus
  6200  Linear Algebra
  6300  Statistics
  6400  Probability
```

## Question type IDs

```
1  mental       — solvable in your head in < 30 s
2  short_answer — 1–3 sentences
3  intermediate — requires working through; show steps
```

## Question difficulty

```
1  easy
2  medium
3  hard
```

## LLM cost accounting

`llm_usage.cost_cents` is `NUMERIC(12, 2)` — decimal cents (e.g. `1000.10` = $10.001).
Token columns mirror Anthropic's usage object: `input_tokens`, `cache_creation_tokens` (~1.25× price), `cache_read_tokens` (~0.1× price), `output_tokens`.

## Key commands

```bash
# Install deps
uv sync --dev

# Lint + format
uv run ruff check . && uv run ruff format .

# Type check
uv run ty check .

# Migrations
uv run alembic revision --autogenerate -m "<message>"
uv run alembic upgrade head
```
