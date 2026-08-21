import asyncio
import json

from fastapi import APIRouter, File, Form, HTTPException, UploadFile
from fastapi.responses import FileResponse, StreamingResponse
from starlette.background import BackgroundTask

from app.config import DOWNLOAD_DIR
from app.services.converter import (
    cancel_job,
    jobs,
    save_upload,
    start_compress_job,
    start_convert_job,
)

router = APIRouter(prefix="/api/convert", tags=["convert"])


@router.post("/upload")
async def upload_file(file: UploadFile = File(...)):
    content = await file.read()
    if len(content) > 500 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="File too large (max 500MB)")
    path = save_upload(file.filename or "upload", content)
    return {"upload_id": path.name}


@router.post("/start")
async def start_convert(upload_id: str = Form(...), target_format: str = Form(...)):
    from app.services.converter import UPLOAD_DIR

    input_path = UPLOAD_DIR / upload_id
    if not input_path.is_file():
        raise HTTPException(status_code=404, detail="Uploaded file not found")

    loop = asyncio.get_running_loop()
    job_id = start_convert_job(input_path, target_format, loop)
    return {"job_id": job_id}


@router.post("/compress/start")
async def start_compress(upload_id: str = Form(...), crf: int = Form(...)):
    from app.services.converter import UPLOAD_DIR

    input_path = UPLOAD_DIR / upload_id
    if not input_path.is_file():
        raise HTTPException(status_code=404, detail="Uploaded file not found")

    loop = asyncio.get_running_loop()
    job_id = start_compress_job(input_path, crf, loop)
    return {"job_id": job_id}


@router.get("/{job_id}/events")
async def convert_events(job_id: str):
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


@router.post("/{job_id}/cancel")
def cancel_convert(job_id: str):
    ok = cancel_job(job_id)
    if not ok:
        raise HTTPException(status_code=404, detail="Job not found")
    return {"cancelled": True}


@router.get("/file/{filename}")
def get_converted_file(filename: str):
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