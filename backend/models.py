import enum

from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    ForeignKey,
    Integer,
    MetaData,
    Numeric,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy import Enum as SAEnum
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.ext.declarative import declarative_base

convention = {
    "ix": "ix_%(table_name)s_%(column_0_N_name)s",
    "uq": "uq_%(table_name)s_%(column_0_N_name)s",
    "ck": "ck_%(table_name)s_%(constraint_name)s",
    "fk": "fk_%(table_name)s_%(column_0_name)s_%(referred_table_name)s",
    "pk": "pk_%(table_name)s",
}

metadata = MetaData(naming_convention=convention)
BaseModel = declarative_base(metadata=metadata)


class ScheduleStatus(enum.StrEnum):
    pending = "pending"
    generating = "generating"
    ready = "ready"
    completed = "completed"


class MessageRole(enum.StrEnum):
    system = "system"
    user_initial_answer = "user_initial_answer"
    user = "user"
    assistant = "assistant"


class TopicType(BaseModel):
    """Lookup table for topic categories. See CLAUDE.md for the numeric ID convention."""

    __tablename__ = "topic_type"

    id = Column(Integer, primary_key=True)
    description = Column(String(128), nullable=True)


class QuestionType(BaseModel):
    """Lookup table for question formats: 1=mental, 2=short_answer, 3=intermediate."""

    __tablename__ = "question_type"

    id = Column(Integer, primary_key=True)
    description = Column(String(128), nullable=True)


class Topic(BaseModel):
    __tablename__ = "topic"

    id = Column(UUID(as_uuid=True), primary_key=True)
    name = Column(String(128), nullable=False)
    topic_type_id = Column(Integer, ForeignKey(TopicType.id), nullable=False)
    description = Column(Text, nullable=True)
    created_at = Column(DateTime(timezone=True), nullable=False)


class DailySchedule(BaseModel):
    """One row per calendar day; status advances as the batch job progresses."""

    __tablename__ = "daily_schedule"

    id = Column(UUID(as_uuid=True), primary_key=True)
    date = Column(Date, nullable=False)
    status = Column(
        SAEnum(ScheduleStatus, name="schedule_status"),
        nullable=False,
        default=ScheduleStatus.pending,
    )
    batch_job_id = Column(String(128), nullable=True)
    generated_at = Column(DateTime(timezone=True), nullable=True)
    ready_at = Column(DateTime(timezone=True), nullable=True)

    __table_args__ = (UniqueConstraint("date"),)


class DailyTopic(BaseModel):
    __tablename__ = "daily_topic"

    id = Column(UUID(as_uuid=True), primary_key=True)
    daily_schedule_id = Column(UUID(as_uuid=True), ForeignKey(DailySchedule.id), nullable=False)
    topic_id = Column(UUID(as_uuid=True), ForeignKey(Topic.id), nullable=False)
    display_order = Column(SmallInteger, nullable=False)


class Question(BaseModel):
    __tablename__ = "question"

    id = Column(UUID(as_uuid=True), primary_key=True)
    topic_id = Column(UUID(as_uuid=True), ForeignKey(Topic.id), nullable=False)
    question_type_id = Column(Integer, ForeignKey(QuestionType.id), nullable=False)
    s3_key = Column(String(512), nullable=False)
    difficulty = Column(SmallInteger, nullable=False)  # 1–3
    prior_question_id = Column(UUID(as_uuid=True), ForeignKey("question.id"), nullable=True)
    daily_schedule_id = Column(UUID(as_uuid=True), ForeignKey(DailySchedule.id), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False)


class ChatSession(BaseModel):
    """
    One thread per question. The first message (role=user_initial_answer) seeds grading;
    subsequent turns are free-form follow-up.
    """

    __tablename__ = "chat_session"

    id = Column(UUID(as_uuid=True), primary_key=True)
    question_id = Column(UUID(as_uuid=True), ForeignKey(Question.id), nullable=False)
    daily_schedule_id = Column(UUID(as_uuid=True), ForeignKey(DailySchedule.id), nullable=False)
    provider = Column(String(32), nullable=False)
    model = Column(String(64), nullable=False)
    is_correct = Column(Boolean, nullable=True)
    time_spent_seconds = Column(SmallInteger, nullable=True)
    started_at = Column(DateTime(timezone=True), nullable=False)
    ended_at = Column(DateTime(timezone=True), nullable=True)


class ChatMessage(BaseModel):
    __tablename__ = "chat_message"

    id = Column(UUID(as_uuid=True), primary_key=True)
    session_id = Column(UUID(as_uuid=True), ForeignKey(ChatSession.id), nullable=False)
    role = Column(SAEnum(MessageRole, name="message_role"), nullable=False)
    content = Column(Text, nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False)
    input_tokens = Column(Integer, nullable=True)
    output_tokens = Column(Integer, nullable=True)


class LLMUsage(BaseModel):
    """
    One row per LLM API call.

    :param cost_cents: decimal cents, e.g. ``1000.10`` = $10.001.
    :param cache_creation_tokens: tokens written to prompt cache (~1.25× input price).
    :param cache_read_tokens: tokens read from prompt cache (~0.1× input price).
    :param ref_id: soft reference to the owning object (batch job, chat session, etc.).
    """

    __tablename__ = "llm_usage"

    id = Column(UUID(as_uuid=True), primary_key=True)
    provider = Column(String(32), nullable=False)
    model = Column(String(64), nullable=False)
    operation = Column(String(64), nullable=False)
    input_tokens = Column(Integer, nullable=False, default=0)
    cache_creation_tokens = Column(Integer, nullable=False, default=0)
    cache_read_tokens = Column(Integer, nullable=False, default=0)
    output_tokens = Column(Integer, nullable=False, default=0)
    cost_cents = Column(Numeric(12, 2), nullable=False)
    created_at = Column(DateTime(timezone=True), nullable=False)
    ref_id = Column(UUID(as_uuid=True), nullable=True)
