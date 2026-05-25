"""Chat endpoints — session creation, SSE streaming, history retrieval."""

import json
import logging
import os
import uuid
from datetime import UTC, datetime

import anthropic
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel as PydanticBase
from sqlalchemy.orm import Session
from sse_starlette.sse import EventSourceResponse

from db import get_db
from models import ChatMessage, ChatSession, LLMUsage, MessageRole, Question
from s3_util import get_question_blob

router = APIRouter()

log = logging.getLogger("chat")

_ANTHROPIC_MODEL = os.getenv("ANTHROPIC_MODEL", "claude-sonnet-4-6")


def _get_anthropic_client() -> anthropic.Anthropic:
    return anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])


class SessionOut(PydanticBase):
    id: uuid.UUID
    question_id: uuid.UUID
    is_correct: bool | None = None
    model_config = {"from_attributes": True}


class MessageOut(PydanticBase):
    id: uuid.UUID
    role: str
    content: str
    created_at: datetime
    model_config = {"from_attributes": True}


class StartSessionIn(PydanticBase):
    question_id: uuid.UUID
    initial_answer: str
    time_spent_seconds: int | None = None


async def _grade_answer(
    prompt: str,
    answer_key: str,
    user_answer: str,
    model: str,
) -> tuple[bool, anthropic.types.Usage]:
    """Call Claude to grade a user answer against the answer key.

    :returns: ``(is_correct, usage)`` — the verdict plus the Anthropic usage
        object so the caller can record cost.
    """
    client = _get_anthropic_client()
    resp = client.messages.create(
        model=model,
        max_tokens=64,
        system=(
            "You are a strict but fair grader. Reply with exactly one word: CORRECT or INCORRECT."
        ),
        messages=[
            {
                "role": "user",
                "content": (
                    f"Question: {prompt}\n\n"
                    f"Answer key: {answer_key}\n\n"
                    f"Student answer: {user_answer}\n\n"
                    "Is the student answer substantially correct?"
                ),
            }
        ],
    )
    text = resp.content[0].text.strip().upper()
    return text.startswith("CORRECT"), resp.usage


@router.post("/sessions", response_model=SessionOut, status_code=201)
async def start_session(body: StartSessionIn, db: Session = Depends(get_db)):
    """Open a chat session, record the user's initial answer, and grade it.

    The question text is stored as the system message; the user's answer as
    ``user_initial_answer``. Grading runs synchronously here so the iOS app can
    read ``is_correct`` from the 201 response.

    :raises HTTPException 404: if the question does not exist.
    """
    question = db.get(Question, body.question_id)
    if not question:
        raise HTTPException(404, "Question not found.")

    blob = get_question_blob(question.s3_key)
    now = datetime.now(UTC)

    session = ChatSession(
        id=uuid.uuid4(),
        question_id=question.id,
        daily_schedule_id=question.daily_schedule_id,
        provider="anthropic",
        model=_ANTHROPIC_MODEL,
        time_spent_seconds=body.time_spent_seconds,
        started_at=now,
    )
    db.add(session)

    db.add(
        ChatMessage(
            id=uuid.uuid4(),
            session_id=session.id,
            role=MessageRole.system,
            content=blob["prompt"],
            created_at=now,
        )
    )
    db.add(
        ChatMessage(
            id=uuid.uuid4(),
            session_id=session.id,
            role=MessageRole.user_initial_answer,
            content=body.initial_answer,
            created_at=now,
        )
    )

    is_correct, usage = await _grade_answer(
        prompt=blob["prompt"],
        answer_key=blob["answer_key"],
        user_answer=body.initial_answer,
        model=_ANTHROPIC_MODEL,
    )
    session.is_correct = is_correct

    # Grading is a tiny standalone call: full rate, no batch discount, no cache.
    input_cost = usage.input_tokens * 3 / 1_000_000 * 100
    output_cost = usage.output_tokens * 15 / 1_000_000 * 100
    db.add(
        LLMUsage(
            id=uuid.uuid4(),
            provider="anthropic",
            model=_ANTHROPIC_MODEL,
            operation="grading",
            input_tokens=usage.input_tokens,
            output_tokens=usage.output_tokens,
            cost_cents=round(input_cost + output_cost, 2),
            created_at=datetime.now(UTC),
            ref_id=session.id,
        )
    )

    db.commit()
    db.refresh(session)
    return session


@router.post("/sessions/{session_id}/messages")
def send_message(session_id: uuid.UUID, body: dict, db: Session = Depends(get_db)):
    """Send a follow-up message and stream the assistant reply via SSE.

    :raises HTTPException 404: if the session does not exist.

    The response is ``text/event-stream``; each event carries a ``delta`` field
    with the next text chunk. A final ``[DONE]`` event signals end-of-stream.
    """
    session = db.get(ChatSession, session_id)
    if not session:
        raise HTTPException(404, "Session not found.")

    user_text: str = body.get("content", "")
    if not user_text:
        raise HTTPException(400, "content is required.")

    history = (
        db.query(ChatMessage)
        .filter(ChatMessage.session_id == session_id)
        .order_by(ChatMessage.created_at)
        .all()
    )

    now = datetime.now(UTC)
    user_msg = ChatMessage(
        id=uuid.uuid4(),
        session_id=session_id,
        role=MessageRole.user,
        content=user_text,
        created_at=now,
    )
    db.add(user_msg)
    db.commit()

    # Build Anthropic messages list (skip system row — passed via system= param)
    system_text = next((m.content for m in history if m.role == MessageRole.system), "")
    messages = [
        {
            "role": "user"
            if m.role in (MessageRole.user, MessageRole.user_initial_answer)
            else "assistant",
            "content": m.content,
        }
        for m in history
        if m.role != MessageRole.system
    ] + [{"role": "user", "content": user_text}]

    client = _get_anthropic_client()

    async def _stream():
        full_text = ""
        usage = None
        log.info(json.dumps({"event": "sse_open", "session_id": str(session_id)}))

        with client.messages.stream(
            model=_ANTHROPIC_MODEL,
            max_tokens=1024,
            system=system_text,
            messages=messages,
        ) as stream:
            for text in stream.text_stream:
                full_text += text
                yield {"event": "delta", "data": json.dumps({"delta": text})}

            final = stream.get_final_message()
            usage = final.usage

        # Persist assistant reply + usage
        assistant_msg = ChatMessage(
            id=uuid.uuid4(),
            session_id=session_id,
            role=MessageRole.assistant,
            content=full_text,
            created_at=datetime.now(UTC),
            input_tokens=usage.input_tokens if usage else None,
            output_tokens=usage.output_tokens if usage else None,
        )
        db.add(assistant_msg)

        if usage:
            # Pricing: Sonnet 4.6 — $3/MTok input, $15/MTok output, cache_read $0.30/MTok
            input_cost = usage.input_tokens * 3 / 1_000_000 * 100
            output_cost = usage.output_tokens * 15 / 1_000_000 * 100
            cache_read = getattr(usage, "cache_read_input_tokens", 0) or 0
            cache_creation = getattr(usage, "cache_creation_input_tokens", 0) or 0
            cache_read_cost = cache_read * 0.30 / 1_000_000 * 100
            cache_creation_cost = cache_creation * 3 * 1.25 / 1_000_000 * 100

            db.add(
                LLMUsage(
                    id=uuid.uuid4(),
                    provider="anthropic",
                    model=_ANTHROPIC_MODEL,
                    operation="chat",
                    input_tokens=usage.input_tokens,
                    cache_creation_tokens=cache_creation,
                    cache_read_tokens=cache_read,
                    output_tokens=usage.output_tokens,
                    cost_cents=round(
                        input_cost + output_cost + cache_read_cost + cache_creation_cost, 2
                    ),
                    created_at=datetime.now(UTC),
                    ref_id=session_id,
                )
            )

        db.commit()
        log.info(
            json.dumps(
                {
                    "event": "sse_close",
                    "session_id": str(session_id),
                    "output_tokens": usage.output_tokens if usage else None,
                }
            )
        )
        yield {"event": "done", "data": "[DONE]"}

    return EventSourceResponse(_stream())


@router.get("/sessions/{session_id}/messages", response_model=list[MessageOut])
def get_history(session_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return full message history for a session, excluding the system prompt."""
    rows = (
        db.query(ChatMessage)
        .filter(
            ChatMessage.session_id == session_id,
            ChatMessage.role != MessageRole.system,
        )
        .order_by(ChatMessage.created_at)
        .all()
    )
    return rows
