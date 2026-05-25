import json
import os

import boto3
from botocore.exceptions import ClientError

_s3 = boto3.client("s3")
_BUCKET = os.environ.get("S3_BUCKET", "")


def get_question_blob(s3_key: str) -> dict:
    """Fetch and deserialise a question JSON blob from S3.

    :param s3_key: S3 object key, e.g. ``questions/{schedule_id}/{question_id}.json``.
    :returns: Parsed question dict with keys ``prompt``, ``answer_key``, ``explanation``, ``options``.
    """
    obj = _s3.get_object(Bucket=_BUCKET, Key=s3_key)
    return json.loads(obj["Body"].read())


def get_article_blob(s3_key: str) -> dict | None:
    """Fetch and deserialise an article JSON blob from S3.

    :param s3_key: S3 object key, e.g. ``articles/{topic_id}.json``.
    :returns: Parsed article dict (``title``, ``body``, ``image_url``, ``source_url``),
        or ``None`` if the object does not exist (article not yet generated).
    """
    try:
        obj = _s3.get_object(Bucket=_BUCKET, Key=s3_key)
    except ClientError as e:
        if e.response["Error"]["Code"] in ("NoSuchKey", "404"):
            return None
        raise
    return json.loads(obj["Body"].read())
