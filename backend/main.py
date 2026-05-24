from fastapi import FastAPI

from routers import chat, schedule, usage

app = FastAPI(title="homer-and-georgia")

app.include_router(schedule.router, prefix="/schedule", tags=["schedule"])
app.include_router(chat.router, prefix="/chat", tags=["chat"])
app.include_router(usage.router, prefix="/usage", tags=["usage"])


@app.get("/health")
def health():
    return {"status": "ok"}
