import asyncio
import json

from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse, StreamingResponse
from starlette.background import BackgroundTask

from app.config import DOWNLOAD_DIR
from app.models.schemas import DownloadRequest, InfoRequest, StartDownloadResponse, VideoInfo
from app.services.downloader import fetch_info
from app.services.job_manager import cancel_download_job, jobs, start_download_job

router = APIRouter(prefix="/api", tags=["download"])


@router.post("/info", response_model=VideoInfo)
def get_info(payload: InfoRequest):
    try:
        return fetch_info(str(payload.url))
    except Exception as exc:
        raise HTTPException(status_code=422, detail=f"Could not fetch info: {exc}") from exc


@router.post("/download/start", response_model=StartDownloadResponse)
async def start_download(payload: DownloadRequest):
    loop = asyncio.get_running_loop()
    job_id = start_download_job(
        str(payload.url), payload.format_id, payload.audio_only, payload.audio_format, loop
    )
    return StartDownloadResponse(job_id=job_id)


@router.post("/download/{job_id}/cancel")
async def cancel_download(job_id: str):
    found = cancel_download_job(job_id)
    if not found:
        raise HTTPException(status_code=404, detail="Job not found")
    return {"status": "cancelling"}


@router.get("/download/{job_id}/events")
async def download_events(job_id: str):
    job = jobs.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="Job not found")

    async def event_stream():
        try:
            while True:
                event = await job.queue.get()
                yield f"data: {json.dumps(event)}\n\n"
                if event["status"] in ("finished", "error", "cancelled"):
                    break
        finally:
            jobs.pop(job_id, None)

    return StreamingResponse(
        event_stream(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache"},
    )


@router.get("/file/{filename}")
def get_file(filename: str):
    path = (DOWNLOAD_DIR / filename).resolve()
    if path.parent != DOWNLOAD_DIR.resolve():
        raise HTTPException(status_code=400, detail="Invalid filename")
    if not path.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    return FileResponse(
        path,
        filename=path.name,
        background=BackgroundTask(path.unlink, missing_ok=True),
    )