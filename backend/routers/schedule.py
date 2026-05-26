"""Schedule and question retrieval endpoints."""

import uuid
from datetime import date

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel as PydanticBase
from sqlalchemy import func
from sqlalchemy.orm import Session

from db import get_db
from models import ChatSession, DailySchedule, DailyTopic, Question, Topic
from s3_util import get_question_blob

router = APIRouter()


class DayOut(PydanticBase):
    id: uuid.UUID
    date: date
    status: str

    model_config = {"from_attributes": True}


class TopicOut(PydanticBase):
    id: uuid.UUID
    name: str
    topic_type_id: int
    description: str | None

    model_config = {"from_attributes": True}


class QuestionOut(PydanticBase):
    id: uuid.UUID
    topic_id: uuid.UUID
    question_type_id: int
    s3_key: str
    difficulty: int
    prior_question_id: uuid.UUID | None

    model_config = {"from_attributes": True}


class QuestionDetailOut(PydanticBase):
    """Full question content fetched from S3, merged with DB metadata."""

    id: uuid.UUID
    topic_id: uuid.UUID
    question_type_id: int
    difficulty: int
    prior_question_id: uuid.UUID | None
    prompt: str
    answer_key: str
    explanation: str
    options: list[str] | None = None


class RevealOut(PydanticBase):
    """Answer key + explanation, shown after the user has submitted."""

    answer_key: str
    explanation: str


class HistoryDayOut(PydanticBase):
    """Summary of a past day — used by the History tab."""

    id: uuid.UUID
    date: date
    status: str
    total_questions: int
    answered: int
    correct: int


@router.get("/history", response_model=list[HistoryDayOut])
def get_history(limit: int = 30, db: Session = Depends(get_db)):
    """Return past schedules with answered/correct counts for the History tab."""
    schedules = (
        db.query(DailySchedule)
        .filter(DailySchedule.date < date.today())
        .order_by(DailySchedule.date.desc())
        .limit(limit)
        .all()
    )

    results = []
    for sched in schedules:
        total = (
            db.query(func.count(Question.id))
            .filter(Question.daily_schedule_id == sched.id)
            .scalar()
            or 0
        )

        answered = (
            db.query(func.count(ChatSession.id))
            .filter(
                ChatSession.daily_schedule_id == sched.id,
                ChatSession.is_correct.isnot(None),
            )
            .scalar()
            or 0
        )

        correct = (
            db.query(func.count(ChatSession.id))
            .filter(
                ChatSession.daily_schedule_id == sched.id,
                ChatSession.is_correct.is_(True),
            )
            .scalar()
            or 0
        )

        results.append(
            HistoryDayOut(
                id=sched.id,
                date=sched.date,
                status=sched.status,
                total_questions=total,
                answered=answered,
                correct=correct,
            )
        )

    return results


@router.get("/today", response_model=DayOut)
def get_today(
    date_param: date | None = Query(default=None, alias="date"),
    db: Session = Depends(get_db),
):
    """Return today's schedule row.

    Accepts an optional ``?date=YYYY-MM-DD`` so the client can pass its local
    date rather than relying on the server's UTC clock.

    :raises HTTPException 404: if no schedule has been generated yet.
    """
    target = date_param or date.today()
    row = db.query(DailySchedule).filter(DailySchedule.date == target).first()
    if not row:
        raise HTTPException(404, "No schedule for today — cron may not have run yet.")
    return row


@router.get("/{schedule_id}/topics", response_model=list[TopicOut])
def get_topics(schedule_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return the ordered topics for a given day."""
    rows = (
        db.query(Topic)
        .join(DailyTopic, DailyTopic.topic_id == Topic.id)
        .filter(DailyTopic.daily_schedule_id == schedule_id)
        .order_by(DailyTopic.display_order)
        .all()
    )
    return rows


@router.get("/{schedule_id}/questions", response_model=list[QuestionOut])
def get_questions(schedule_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return all questions for a given day."""
    rows = db.query(Question).filter(Question.daily_schedule_id == schedule_id).all()
    return rows


@router.get("/questions/{question_id}", response_model=QuestionDetailOut)
def get_question_detail(question_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return full question content (prompt, answer key, explanation) from S3.

    :raises HTTPException 404: if the question does not exist.
    """
    question = db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "Question not found.")
    blob = get_question_blob(question.s3_key)
    return QuestionDetailOut(
        id=question.id,
        topic_id=question.topic_id,
        question_type_id=question.question_type_id,
        difficulty=question.difficulty,
        prior_question_id=question.prior_question_id,
        **blob,
    )


@router.get("/questions/{question_id}/reveal", response_model=RevealOut)
def reveal_answer(question_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return the answer key and explanation for a question.

    Gated on the user having already submitted: only callable once a
    ``chat_session`` exists for this question.

    :raises HTTPException 404: if the question or its chat session does not exist.
    """
    question = db.get(Question, question_id)
    if not question:
        raise HTTPException(404, "Question not found.")

    session_exists = db.query(ChatSession.id).filter(ChatSession.question_id == question_id).first()
    if not session_exists:
        raise HTTPException(404, "No session for this question yet — submit an answer first.")

    blob = get_question_blob(question.s3_key)
    return RevealOut(answer_key=blob["answer_key"], explanation=blob["explanation"])
