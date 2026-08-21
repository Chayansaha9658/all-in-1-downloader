from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import ALLOWED_ORIGINS, clear_download_dir
from app.routers import convert, download

app = FastAPI(title="All in 1 Downloader API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=ALLOWED_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(download.router)
app.include_router(convert.router)


@app.on_event("startup")
def _startup() -> None:
    clear_download_dir()


@app.get("/api/health")
def health():
    return {"status": "ok"}