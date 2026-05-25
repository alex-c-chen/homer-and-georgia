"""Topic-level content endpoints (educational articles)."""

import uuid

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel as PydanticBase
from sqlalchemy.orm import Session

from db import get_db
from models import Topic
from s3_util import get_article_blob

router = APIRouter()


class ArticleOut(PydanticBase):
    title: str
    body: str  # markdown prose
    image_url: str | None
    source_url: str


@router.get("/{topic_id}/article", response_model=ArticleOut)
def get_article(topic_id: uuid.UUID, db: Session = Depends(get_db)):
    """Return the educational article for a topic, fetched from S3.

    :raises HTTPException 404: if the topic is unknown, is a math topic
        (``topic_type_id >= 6000``, which has no article), or has no article
        generated in S3 yet.
    """
    topic = db.get(Topic, topic_id)
    if not topic:
        raise HTTPException(404, "Topic not found.")
    if topic.topic_type_id >= 6000:
        raise HTTPException(404, "Math topics have no article.")

    blob = get_article_blob(f"articles/{topic_id}.json")
    if blob is None:
        raise HTTPException(404, "Article not generated yet.")
    return ArticleOut(**blob)
