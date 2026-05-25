"""
Nightly question generation worker.

Called by GitHub Actions at 2 AM Eastern::

    uv run python cron.py

Flow:
  1. Create a DailySchedule row for tomorrow.
  2. Pick 5–10 topics via rotation logic (seeded in seed.py).
  3. Submit an Anthropic Batch request — one request per (topic, question_type, difficulty).
  4. Poll until the batch is complete, then write each question's JSON to S3
     and insert Question rows pointing at it.
  5. Advance schedule status to ``ready``.
"""

import json
import logging
import os
import time
import uuid
from datetime import UTC, date, datetime, timedelta

import anthropic
import boto3

from db import SessionLocal
from models import (
    DailySchedule,
    DailyTopic,
    LLMUsage,
    Question,
    ScheduleStatus,
    Topic,
    TopicType,
)

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("cron")

_ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-6")
_S3_BUCKET = os.environ["S3_BUCKET"]
_TOPICS_PER_DAY = int(os.getenv("TOPICS_PER_DAY", "7"))

# Question matrix per topic: (question_type_id, difficulty)
_QUESTION_MATRIX = [
    (1, 1),  # mental / easy
    (2, 2),  # short_answer / medium
    (3, 3),  # intermediate / hard
]

_SYSTEM_PROMPT = """\
You are a rigorous tutor generating study questions. Given a topic, return a JSON object with:
  "prompt"     – the question text
  "answer_key" – the ideal answer (concise)
  "explanation"– 2–3 sentence explanation of the concept
  "options"    – list of 4 strings for MCQ (omit if not multiple choice)
Return only valid JSON, no markdown fences.\
"""

_USER_PROMPT_TEMPLATE = """\
Topic: {topic_name}
Topic description: {topic_description}
Question type: {question_type}  (1=mental/quick, 2=short_answer, 3=intermediate/show-steps)
Difficulty: {difficulty}  (1=easy, 2=medium, 3=hard)
Generate one question.\
"""


def _pick_topics(db, schedule_date: date, n: int) -> list[Topic]:
    """Rotate topics deterministically by day-of-year, favouring math on weekdays."""
    all_topics: list[Topic] = db.query(Topic).join(TopicType).all()
    # Math topics (6xxx) always included Mon–Fri
    math = [t for t in all_topics if t.topic_type_id >= 6000]
    general = [t for t in all_topics if t.topic_type_id < 6000]

    seed_offset = schedule_date.timetuple().tm_yday
    rotated_general = general[seed_offset % len(general) :] + general[: seed_offset % len(general)]

    if schedule_date.weekday() < 5:  # Mon–Fri: include math
        math_pick = math[:2]
        general_pick = rotated_general[: n - len(math_pick)]
        return math_pick + general_pick
    else:  # Weekend: all general
        return rotated_general[:n]


def _build_batch_requests(
    topics: list[Topic],
) -> list[anthropic.types.MessageCreateParamsNonStreaming]:
    requests = []
    for topic in topics:
        for qt_id, difficulty in _QUESTION_MATRIX:
            qt_label = {1: "mental", 2: "short_answer", 3: "intermediate"}[qt_id]
            requests.append(
                {
                    "custom_id": f"{topic.id}|{qt_id}|{difficulty}",
                    "params": {
                        "model": _ANTHROPIC_MODEL,
                        "max_tokens": 512,
                        "system": _SYSTEM_PROMPT,
                        "messages": [
                            {
                                "role": "user",
                                "content": _USER_PROMPT_TEMPLATE.format(
                                    topic_name=topic.name,
                                    topic_description=topic.description or "",
                                    question_type=qt_label,
                                    difficulty=difficulty,
                                ),
                            }
                        ],
                    },
                }
            )
    return requests


def run():
    db = SessionLocal()
    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    s3 = boto3.client("s3")

    tomorrow = date.today() + timedelta(days=1)
    now = datetime.now(UTC)

    # Idempotent: skip if already generated
    existing = db.query(DailySchedule).filter(DailySchedule.date == tomorrow).first()
    if existing and existing.status not in (ScheduleStatus.pending,):
        log.info(
            json.dumps({"event": "skip", "date": str(tomorrow), "status": str(existing.status)})
        )
        return

    schedule = existing or DailySchedule(
        id=uuid.uuid4(),
        date=tomorrow,
        status=ScheduleStatus.pending,
    )
    if not existing:
        db.add(schedule)

    topics = _pick_topics(db, tomorrow, _TOPICS_PER_DAY)
    for i, topic in enumerate(topics):
        db.add(
            DailyTopic(
                id=uuid.uuid4(),
                daily_schedule_id=schedule.id,
                topic_id=topic.id,
                display_order=i,
            )
        )

    schedule.status = ScheduleStatus.generating
    schedule.generated_at = now
    db.commit()

    # Submit batch
    requests = _build_batch_requests(topics)
    batch = client.messages.batches.create(requests=requests)
    schedule.batch_job_id = batch.id
    db.commit()
    log.info(
        json.dumps(
            {"event": "batch_submitted", "batch_id": batch.id, "request_count": len(requests)}
        )
    )

    # Poll until complete (max ~12 min)
    for attempt in range(72):
        time.sleep(10)
        batch = client.messages.batches.retrieve(batch.id)
        log.info(
            json.dumps(
                {
                    "event": "batch_poll",
                    "elapsed_seconds": attempt * 10,
                    "status": batch.processing_status,
                }
            )
        )
        if batch.processing_status == "ended":
            break
    else:
        raise TimeoutError(f"Batch {batch.id} did not complete within 12 minutes.")

    # Process results
    total_input = total_output = total_cache_read = total_cache_creation = 0
    for result in client.messages.batches.results(batch.id):
        if result.result.type != "succeeded":
            log.warning(
                json.dumps(
                    {
                        "event": "request_failed",
                        "custom_id": result.custom_id,
                        "type": result.result.type,
                    }
                )
            )
            continue

        topic_id_str, qt_id_str, difficulty_str = result.custom_id.split("|")
        msg = result.result.message
        usage = msg.usage
        total_input += usage.input_tokens
        total_output += usage.output_tokens
        total_cache_read += getattr(usage, "cache_read_input_tokens", 0) or 0
        total_cache_creation += getattr(usage, "cache_creation_input_tokens", 0) or 0

        try:
            blob = json.loads(msg.content[0].text)
        except (json.JSONDecodeError, IndexError) as e:
            log.warning(
                json.dumps({"event": "bad_json", "custom_id": result.custom_id, "error": str(e)})
            )
            continue

        question_id = uuid.uuid4()
        s3_key = f"questions/{schedule.id}/{question_id}.json"
        s3.put_object(
            Bucket=_S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(blob),
            ContentType="application/json",
        )

        db.add(
            Question(
                id=question_id,
                topic_id=uuid.UUID(topic_id_str),
                question_type_id=int(qt_id_str),
                s3_key=s3_key,
                difficulty=int(difficulty_str),
                daily_schedule_id=schedule.id,
                created_at=now,
            )
        )

    # Record usage (batch pricing: 50% off standard)
    input_cost = total_input * 3 * 0.5 / 1_000_000 * 100
    output_cost = total_output * 15 * 0.5 / 1_000_000 * 100
    cache_read_cost = total_cache_read * 0.30 * 0.5 / 1_000_000 * 100
    cache_creation_cost = total_cache_creation * 3 * 1.25 * 0.5 / 1_000_000 * 100
    cost_cents = round(input_cost + output_cost + cache_read_cost + cache_creation_cost, 2)

    db.add(
        LLMUsage(
            id=uuid.uuid4(),
            provider="anthropic",
            model=_ANTHROPIC_MODEL,
            operation="batch_generation",
            input_tokens=total_input,
            cache_creation_tokens=total_cache_creation,
            cache_read_tokens=total_cache_read,
            output_tokens=total_output,
            cost_cents=cost_cents,
            created_at=now,
            ref_id=schedule.id,
        )
    )

    schedule.status = ScheduleStatus.ready
    schedule.ready_at = datetime.now(UTC)
    db.commit()
    log.info(
        json.dumps(
            {
                "event": "batch_complete",
                "date": str(tomorrow),
                "request_count": len(requests),
                "total_input_tokens": total_input,
                "total_output_tokens": total_output,
                "cost_cents": float(cost_cents),
            }
        )
    )


if __name__ == "__main__":
    run()
