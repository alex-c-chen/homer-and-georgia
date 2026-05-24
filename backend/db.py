import os

from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

_engine = create_engine(os.environ["DATABASE_URL"], pool_pre_ping=True)
SessionLocal = sessionmaker(bind=_engine, autocommit=False, autoflush=False)


def get_db():
    """Yield a DB session; close on exit.

    :yields: :class:`sqlalchemy.orm.Session`
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
