# Handoff Index — Homer & Georgia

Each file in this directory is a self-contained spec for one work stream.
An agent can pick up any handoff and execute it without reading the conversation history.
Read the relevant handoff file, then read the files it references, then build.

## Handoffs

| File | Work stream | Depends on |
|---|---|---|
| [`01-ios-app.md`](01-ios-app.md) | Build the full SwiftUI iOS app | Backend deployed |
| [`02-backend-grading.md`](02-backend-grading.md) | Add LLM answer grading + auth | Backend deployed |
| [`03-topic-seeding.md`](03-topic-seeding.md) | Seed initial topics + design math curriculum | Backend running locally |
| [`04-infra-bootstrap.md`](04-infra-bootstrap.md) | Provision AWS, deploy Fly.io, wire secrets | AWS + Fly.io accounts |

## Project snapshot

```
homer-and-georgia/
├── backend/          FastAPI, SQLAlchemy, Alembic — BUILT, not yet deployed
├── infrastructure/   Terraform (S3 + IAM) — WRITTEN, not yet applied
├── ios/              Swift stubs only — needs full implementation
├── CLAUDE.md         Code conventions (read this first)
├── mockup.html       6-screen iOS UI reference — open in browser
├── architecture.html System diagram — open in browser
└── TODO.md           Full task list
```

## Conventions (apply to all handoffs)

- Python: Sphinx docstrings, terse comments, ruff + ty, `uv` for deps
- Swift: SwiftUI, iOS 17+, `@Observable`, async/await, no third-party packages
- Git: commit after each logical chunk; co-author line required (see below)
- Never commit `.env`, `*.tfvars`, `*.tfstate` files

### Required git commit footer
```
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
```
