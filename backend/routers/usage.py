"""Cost dashboard — aggregates LLM, AWS, and Neon spend."""

from decimal import Decimal

import boto3
from fastapi import APIRouter, Depends
from pydantic import BaseModel as PydanticBase
from sqlalchemy import func
from sqlalchemy.orm import Session

from db import get_db
from models import LLMUsage

router = APIRouter()


class LLMBreakdown(PydanticBase):
    total_cents: float
    by_operation: dict[str, float]


class AWSBreakdown(PydanticBase):
    total_cents: float
    by_service: dict[str, float]


class UsageSummary(PydanticBase):
    llm: LLMBreakdown
    aws: AWSBreakdown
    total_cents: float


def _get_llm_summary(db: Session) -> LLMBreakdown:
    rows = (
        db.query(LLMUsage.operation, func.sum(LLMUsage.cost_cents))
        .group_by(LLMUsage.operation)
        .all()
    )
    by_op = {op: float(total) for op, total in rows}
    return LLMBreakdown(total_cents=sum(by_op.values()), by_operation=by_op)


def _get_aws_summary() -> AWSBreakdown:
    """Pull month-to-date costs from AWS Cost Explorer.

    :returns: Breakdown by AWS service in cents.
    :raises: passes through boto3 exceptions if Cost Explorer is unreachable.
    """
    ce = boto3.client("ce", region_name="us-east-1")
    from datetime import date

    today = date.today()
    start = today.replace(day=1).isoformat()
    end = today.isoformat()

    # Cost Explorer returns zero-length results if start == end (first of month)
    if start == end:
        return AWSBreakdown(total_cents=0.0, by_service={})

    try:
        resp = ce.get_cost_and_usage(
            TimePeriod={"Start": start, "End": end},
            Granularity="MONTHLY",
            Metrics=["UnblendedCost"],
            GroupBy=[{"Type": "DIMENSION", "Key": "SERVICE"}],
        )
    except ce.exceptions.DataUnavailableException:
        # Cost Explorer returns this for ~24 h after first being enabled.
        return AWSBreakdown(total_cents=0.0, by_service={})

    by_service: dict[str, float] = {}
    for group in resp["ResultsByTime"][0]["Groups"]:
        service = group["Keys"][0]
        usd = Decimal(group["Metrics"]["UnblendedCost"]["Amount"])
        by_service[service] = float(usd * 100)  # dollars → cents

    return AWSBreakdown(total_cents=sum(by_service.values()), by_service=by_service)


@router.get("/summary", response_model=UsageSummary)
def get_summary(db: Session = Depends(get_db)):
    """Return month-to-date spend across LLM APIs and AWS."""
    llm = _get_llm_summary(db)
    aws = _get_aws_summary()
    return UsageSummary(
        llm=llm,
        aws=aws,
        total_cents=llm.total_cents + aws.total_cents,
    )
