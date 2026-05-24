import json
import os

import boto3

_s3 = boto3.client("s3")
_BUCKET = os.environ.get("S3_BUCKET", "")


def get_question_blob(s3_key: str) -> dict:
    """Fetch and deserialise a question JSON blob from S3.

    :param s3_key: S3 object key, e.g. ``questions/{schedule_id}/{question_id}.json``.
    :returns: Parsed question dict with keys ``prompt``, ``answer_key``, ``explanation``, ``options``.
    """
    obj = _s3.get_object(Bucket=_BUCKET, Key=s3_key)
    return json.loads(obj["Body"].read())
