# TODO

Tracked by vertical. Items are roughly in dependency order.

---

## Infrastructure

- [ ] `terraform apply` against AWS account, capture IAM credentials from outputs
- [ ] Add `terraform.tfvars` for prod values (gitignored)
- [ ] Consider moving Terraform state to S3 backend when project stabilises
- [ ] Add S3 lifecycle rule to expire old question blobs after 90 days

---

## Backend

### Bootstrap
- [ ] Create Neon project, copy connection string
- [ ] Set Fly.io + GitHub secrets (see `backend/README.md` env var table)
- [ ] Run `alembic upgrade head` against Neon
- [ ] Run `seed.py` to populate `topic_type` and `question_type`
- [ ] `fly deploy` first deploy, verify `/health` returns `{"status":"ok"}`

### Topics
- [ ] Seed actual `topic` rows (e.g. "Otto von Bismarck", "Integration by Parts", "WWI — Triple Alliance")
- [ ] Design 6–8 week general-knowledge topic rotation
- [ ] Design math curriculum progression (Calculus → Linear Algebra → Statistics → Probability)

### Cron / question generation
- [ ] Test `cron.py` manually with `workflow_dispatch` before relying on schedule
- [ ] Tune `_SYSTEM_PROMPT` based on first real batch output
- [ ] Add LLM-based answer grading step (currently `is_correct` is null for subjective questions)
- [ ] Handle batch timeout > 12 min (consider splitting into submit + poll as two separate GitHub Actions steps)
- [ ] Add error alerting when batch fails (GitHub Actions email on failure is enough for now)

### API
- [ ] Add simple auth (bearer token or Cognito) to all endpoints before sharing URL
- [ ] Add pagination to `GET /schedule/{id}/questions` once question count grows
- [ ] Cache `/usage/summary` for 1 hour (AWS Cost Explorer has rate limits)
- [ ] Add `GET /schedule/questions/{id}/reveal` endpoint that returns `answer_key` (for self-check after answering)

### Quality
- [ ] Write integration tests against a test Neon branch (Neon branching makes this easy)
- [ ] Add structured logging (JSON to stdout; Fly.io ships to any log sink)

---

## iOS App

### Project setup
- [ ] Create Xcode project, add all files from `ios/HomerAndGeorgia/`
- [ ] Set deployment target to iOS 17
- [ ] Configure `API_BASE_URL` in Debug scheme env vars pointing to `localhost:8080`
- [ ] Add app icon + launch screen

### Screens to build (see `mockup.html`)
- [ ] `TodayView` — topic list with General + Math sections, progress chip
- [ ] `TopicDetailView` — 3 questions per topic, prior-topic link
- [ ] `QuestionView` — MCQ for mental questions, free-text for short/intermediate
- [ ] `ChatView` — SSE streaming, grade banner (✓/✗), follow-up input
- [ ] `UsageView` — total spend, LLM breakdown, AWS breakdown

### Networking
- [ ] Implement `APIClient` with all endpoints
- [ ] Implement SSE streaming in `ChatViewModel` using `URLSession.bytes`
- [ ] Add offline / no-schedule-yet state handling (schedule won't exist until cron runs)
- [ ] Persist today's schedule ID locally (UserDefaults) to avoid refetching on relaunch

### Polish
- [ ] Add haptics on answer submit and correct/incorrect grade
- [ ] Add push notification at 8:30 AM ("Your questions are ready")
- [ ] Support Dynamic Type for accessibility
- [ ] Dark mode QA pass

---

## Later / Nice-to-have

- [ ] Neon usage in `/usage/summary` (Neon Management API is in beta)
- [ ] Streak tracking — days answered in a row
- [ ] "Review past questions" screen — browse by topic or date
- [ ] Share a question as an image
- [ ] watchOS companion for the mental/MCQ questions
