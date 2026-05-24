"""
Seed data for lookup tables.

Run once against a fresh database::

    uv run python seed.py

Topic type IDs follow the convention in CLAUDE.md:
  1xxx  Persons & Organizations  (xxx = ISO 3166-1 numeric country code)
  2xxx  Historical Events        (xxx = primary country code)
  3xxx  Geography                (xxx = country code)
  41xx  Visual Arts
  42xx  Music
  43xx  Dance & Performing Arts
  44xx  Literature
  45xx  Film & Media
  51xx  Physics / 52xx Chemistry / 53xx Biology / 54xx Earth & Space
  6100  Calculus / 6200  Linear Algebra / 6300  Statistics / 6400  Probability
"""

from db import SessionLocal
from models import QuestionType, TopicType

TOPIC_TYPES = [
    # Persons & Organizations
    (1000, "Persons & Orgs — International / Ancient"),
    (1156, "Persons & Orgs — China"),
    (1250, "Persons & Orgs — France"),
    (1276, "Persons & Orgs — Germany"),
    (1356, "Persons & Orgs — India"),
    (1380, "Persons & Orgs — Italy"),
    (1392, "Persons & Orgs — Japan"),
    (1410, "Persons & Orgs — South Korea"),
    (1724, "Persons & Orgs — Spain"),
    (1826, "Persons & Orgs — United Kingdom"),
    (1840, "Persons & Orgs — United States"),
    # Historical Events
    (2000, "Historical Events — Global"),
    (2250, "Historical Events — France"),
    (2276, "Historical Events — Germany"),
    (2356, "Historical Events — India"),
    (2826, "Historical Events — United Kingdom"),
    (2840, "Historical Events — United States"),
    # Geography
    (3000, "Geography — Global / Oceans"),
    (3156, "Geography — China"),
    (3250, "Geography — France"),
    (3276, "Geography — Germany"),
    (3356, "Geography — India"),
    (3380, "Geography — Italy"),
    (3392, "Geography — Japan"),
    (3826, "Geography — United Kingdom"),
    (3840, "Geography — United States"),
    # Arts
    (4100, "Visual Arts"),
    (4200, "Music"),
    (4300, "Dance & Performing Arts"),
    (4400, "Literature"),
    (4500, "Film & Media"),
    # Science
    (5100, "Physics"),
    (5200, "Chemistry"),
    (5300, "Biology"),
    (5400, "Earth & Space Science"),
    # Mathematics
    (6100, "Calculus"),
    (6200, "Linear Algebra"),
    (6300, "Statistics"),
    (6400, "Probability"),
]

QUESTION_TYPES = [
    (1, "mental"),
    (2, "short_answer"),
    (3, "intermediate"),
]


def seed():
    db = SessionLocal()
    try:
        for id_, description in TOPIC_TYPES:
            if not db.get(TopicType, id_):
                db.add(TopicType(id=id_, description=description))

        for id_, description in QUESTION_TYPES:
            if not db.get(QuestionType, id_):
                db.add(QuestionType(id=id_, description=description))

        db.commit()
        print(f"Seeded {len(TOPIC_TYPES)} topic types, {len(QUESTION_TYPES)} question types.")
    finally:
        db.close()


if __name__ == "__main__":
    seed()
