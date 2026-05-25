"""Insert fake dev data for local simulator testing.

Creates 2 general + 1 math topic, a daily_schedule for today,
and 3 questions per topic with blobs uploaded to S3.

Usage:
    DATABASE_URL=... S3_BUCKET=... uv run python dev_seed.py
"""

import json
import os
import uuid
from datetime import UTC, date, datetime

import boto3
from sqlalchemy import create_engine
from sqlalchemy.orm import Session

from models import (
    DailySchedule,
    DailyTopic,
    Question,
    ScheduleStatus,
    Topic,
)

DATABASE_URL = os.environ["DATABASE_URL"]
S3_BUCKET = os.environ.get("S3_BUCKET", "homer-and-georgia-prod-questions")

engine = create_engine(DATABASE_URL)
s3 = boto3.client("s3")

TOPICS = [
    {
        "name": "Marie Curie",
        "topic_type_id": 1250,
        "description": "First woman to win a Nobel Prize, and the only person to win in two sciences (Physics 1903, Chemistry 1911). Discovered polonium and radium; pioneered radioactivity research.",
        "questions": [
            {
                "question_type_id": 1,  # mental
                "difficulty": 1,
                "prompt": "How many Nobel Prizes did Marie Curie win, and in which fields?",
                "answer_key": "Two — Physics (1903) and Chemistry (1911).",
                "explanation": "Curie won the Nobel Prize in Physics in 1903 (shared with Pierre Curie and Henri Becquerel) for their research on radiation, and the Nobel Prize in Chemistry in 1911 for the discovery of radium and polonium. She remains the only person to have won Nobel Prizes in two different sciences.",
                "options": ["One — Physics", "Two — Physics and Chemistry", "Two — Chemistry and Medicine", "Three — Physics, Chemistry, and Peace"],
            },
            {
                "question_type_id": 2,  # short_answer
                "difficulty": 2,
                "prompt": "What two elements did Marie Curie discover, and how did she name them?",
                "answer_key": "Polonium (named after her homeland Poland) and radium (named for its intense radioactivity).",
                "explanation": "Curie isolated polonium in 1898, naming it after Poland — then under Russian, German, and Austro-Hungarian partition — as a political statement. She isolated radium later that year, naming it from the Latin 'radius' (ray) for its powerful radioactive emissions.",
                "options": None,
            },
            {
                "question_type_id": 3,  # intermediate
                "difficulty": 3,
                "prompt": "Explain how Marie Curie's wartime X-ray units worked and why they were significant.",
                "answer_key": "She developed mobile X-ray units ('petites Curies') powered by car engines that brought field radiography to the Western Front, allowing surgeons to locate bullets and shrapnel without exploratory surgery. This saved countless lives and demonstrated the practical military value of radiology.",
                "explanation": "During WWI, Curie recognised that X-ray technology could save soldiers if it could be brought to the front rather than transporting wounded men to distant hospitals. She personally trained 150 female radiologists and drove the units herself. The 'petites Curies' performed over a million X-rays during the war.",
                "options": None,
            },
        ],
    },
    {
        "name": "Special Relativity",
        "topic_type_id": 5100,
        "description": "Einstein's 1905 theory based on two postulates: the speed of light is constant in all inertial frames, and the laws of physics are the same in all inertial frames. Key consequences: time dilation, length contraction, E=mc².",
        "questions": [
            {
                "question_type_id": 1,  # mental
                "difficulty": 1,
                "prompt": "What does E=mc² mean in plain English?",
                "answer_key": "Mass and energy are equivalent and interconvertible; a small amount of mass corresponds to a large amount of energy (because c² is enormous).",
                "explanation": "E=mc² states that the energy (E) of an object at rest equals its mass (m) multiplied by the speed of light squared (c² ≈ 9×10¹⁶ m²/s²). Because c² is so large, even a tiny mass contains a huge amount of energy — the principle behind nuclear reactions.",
                "options": ["Energy equals mass times the speed of light", "Mass and energy are equivalent", "Energy is always conserved", "The speed of light equals mass times energy"],
            },
            {
                "question_type_id": 2,  # short_answer
                "difficulty": 2,
                "prompt": "What are the two postulates of special relativity?",
                "answer_key": "1) The laws of physics are the same in all inertial (non-accelerating) reference frames. 2) The speed of light in a vacuum is constant (c ≈ 3×10⁸ m/s) for all observers, regardless of the motion of the light source.",
                "explanation": "Einstein published these postulates in his 1905 paper 'On the Electrodynamics of Moving Bodies.' The first postulate generalises Galilean relativity to all physics (not just mechanics). The second breaks with Newtonian intuition — velocities don't simply add when light is involved.",
                "options": None,
            },
            {
                "question_type_id": 3,  # intermediate
                "difficulty": 3,
                "prompt": "A spaceship travels at 0.6c relative to Earth. An astronaut on board measures the trip as taking 4 years. How long does the trip take according to an observer on Earth? Show your reasoning.",
                "answer_key": "5 years. Time dilation: t = γ·τ where γ = 1/√(1−v²/c²) = 1/√(1−0.36) = 1/√0.64 = 1/0.8 = 1.25. So t = 1.25 × 4 = 5 years.",
                "explanation": "The Lorentz factor γ = 1/√(1−v²/c²). With v=0.6c: γ = 1/√(1−0.36) = 1/0.8 = 1.25. The Earth observer sees the astronaut's clock running slow by factor γ, so their 4 proper years correspond to 4×1.25 = 5 Earth years. This is the 'twin paradox' setup — the travelling twin ages less.",
                "options": None,
            },
        ],
    },
    {
        "name": "Limits & Continuity",
        "topic_type_id": 6100,
        "description": "Foundation of calculus: the ε-δ definition of a limit, one-sided limits, limit laws, and the three conditions for continuity at a point.",
        "questions": [
            {
                "question_type_id": 1,  # mental
                "difficulty": 1,
                "prompt": "What is lim(x→2) of (x² − 4)/(x − 2)?",
                "answer_key": "4",
                "explanation": "Factor the numerator: (x²−4)/(x−2) = (x+2)(x−2)/(x−2) = x+2 for x≠2. As x→2, x+2→4. The limit is 4, even though the function is undefined at x=2.",
                "options": ["0", "2", "4", "Undefined"],
            },
            {
                "question_type_id": 2,  # short_answer
                "difficulty": 2,
                "prompt": "State the three conditions required for a function f to be continuous at a point x=a.",
                "answer_key": "1) f(a) is defined. 2) lim(x→a) f(x) exists. 3) lim(x→a) f(x) = f(a).",
                "explanation": "All three conditions must hold simultaneously. Violating any one produces a discontinuity: undefined f(a) is a hole or break; a non-existent limit (left ≠ right) is a jump discontinuity; limit existing but not equalling f(a) is a removable discontinuity.",
                "options": None,
            },
            {
                "question_type_id": 3,  # intermediate
                "difficulty": 3,
                "prompt": "Using the ε-δ definition, prove that lim(x→3) (2x − 1) = 5.",
                "answer_key": "We need: for every ε>0, find δ>0 such that 0<|x−3|<δ implies |(2x−1)−5|<ε. |(2x−1)−5| = |2x−6| = 2|x−3|. So choose δ=ε/2. Then 0<|x−3|<δ implies |2x−6| = 2|x−3| < 2·(ε/2) = ε. □",
                "explanation": "The key step is algebraically simplifying |f(x)−L| in terms of |x−a|, which reveals the relationship between δ and ε. Here |f(x)−L| = 2|x−a|, so we need 2δ ≤ ε, giving δ = ε/2. This is a linear function so the proof is clean — polynomial functions require bounding extra terms.",
                "options": None,
            },
        ],
    },
]


def run():
    now = datetime.now(UTC)
    today = date.today()

    with Session(engine) as db:
        # Daily schedule for today
        existing = db.query(DailySchedule).filter(DailySchedule.date == today).first()
        if existing:
            print(f"Schedule for {today} already exists — clearing questions and rebuilding.")
            db.query(Question).filter(Question.daily_schedule_id == existing.id).delete()
            db.query(DailyTopic).filter(DailyTopic.daily_schedule_id == existing.id).delete()
            schedule = existing
            schedule.status = ScheduleStatus.ready
            schedule.generated_at = now
            schedule.ready_at = now
        else:
            schedule = DailySchedule(
                id=uuid.uuid4(),
                date=today,
                status=ScheduleStatus.ready,
                generated_at=now,
                ready_at=now,
            )
            db.add(schedule)

        db.flush()

        for order, topic_data in enumerate(TOPICS):
            # Upsert topic
            topic = db.query(Topic).filter(Topic.name == topic_data["name"]).first()
            if not topic:
                topic = Topic(
                    id=uuid.uuid4(),
                    name=topic_data["name"],
                    topic_type_id=topic_data["topic_type_id"],
                    description=topic_data["description"],
                    created_at=now,
                )
                db.add(topic)
                db.flush()

            daily_topic = DailyTopic(
                id=uuid.uuid4(),
                daily_schedule_id=schedule.id,
                topic_id=topic.id,
                display_order=order,
            )
            db.add(daily_topic)

            for q_data in topic_data["questions"]:
                q_id = uuid.uuid4()
                s3_key = f"questions/{schedule.id}/{q_id}.json"

                blob = {
                    "prompt": q_data["prompt"],
                    "answer_key": q_data["answer_key"],
                    "explanation": q_data["explanation"],
                    "options": q_data["options"],
                }
                s3.put_object(
                    Bucket=S3_BUCKET,
                    Key=s3_key,
                    Body=json.dumps(blob),
                    ContentType="application/json",
                )

                question = Question(
                    id=q_id,
                    topic_id=topic.id,
                    question_type_id=q_data["question_type_id"],
                    s3_key=s3_key,
                    difficulty=q_data["difficulty"],
                    daily_schedule_id=schedule.id,
                    created_at=now,
                )
                db.add(question)
                print(f"  ✓ {topic_data['name']} — Q{q_data['question_type_id']} (difficulty {q_data['difficulty']})")

        db.commit()

    print(f"\nDev data ready for {today}. Start backend and open simulator.")


if __name__ == "__main__":
    run()
