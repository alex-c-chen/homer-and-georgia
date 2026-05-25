import json
import logging
from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI

from auth import require_auth
from routers import chat, schedule, topics, usage

logging.basicConfig(level=logging.INFO, format="%(message)s")
log = logging.getLogger("app")


@asynccontextmanager
async def lifespan(app: FastAPI):
    log.info(json.dumps({"event": "startup", "service": "homer-and-georgia"}))
    yield


app = FastAPI(title="homer-and-georgia", lifespan=lifespan)

app.include_router(
    schedule.router, prefix="/schedule", tags=["schedule"], dependencies=[Depends(require_auth)]
)
app.include_router(chat.router, prefix="/chat", tags=["chat"], dependencies=[Depends(require_auth)])
app.include_router(
    topics.router, prefix="/topics", tags=["topics"], dependencies=[Depends(require_auth)]
)
app.include_router(
    usage.router, prefix="/usage", tags=["usage"], dependencies=[Depends(require_auth)]
)


@app.get("/health")
def health():
    return {"status": "ok"}
