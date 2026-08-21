import asyncio
import re
import threading
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

from app.config import DOWNLOAD_DIR

_DURATION_RE = re.compile(r"Duration: (\d+):(\d+):(\d+)\.(\d+)")
_TIME_RE = re.compile(r"time=(\d+):(\d+):(\d+)\.(\d+)")

UPLOAD_DIR = DOWNLOAD_DIR.parent / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)


@dataclass
class ConvertJob:
    job_id: str
    queue: "asyncio.Queue[dict]"
    loop: asyncio.AbstractEventLoop = field(repr=False)
    cancel_event: threading.Event = field(default_factory=threading.Event)


jobs: dict[str, ConvertJob] = {}


def _emit(job: ConvertJob, event: dict) -> None:
    job.loop.call_soon_threadsafe(job.queue.put_nowait, event)


def _parse_timestamp(match: "re.Match[str]") -> float:
    h, m, s, frac = match.groups()
    return int(h) * 3600 + int(m) * 60 + int(s) + int(frac) / (10 ** len(frac))


def save_upload(filename: str, content: bytes) -> Path:
    safe_name = re.sub(r'[\\/:*?"<>|]', "", filename or "upload")
    short_id = uuid.uuid4().hex[:8]
    path = UPLOAD_DIR / f"{short_id}-{safe_name}"
    path.write_bytes(content)
    return path


def start_convert_job(
    input_path: Path,
    target_format: str,
    loop: asyncio.AbstractEventLoop,
) -> str:
    job_id = uuid.uuid4().hex
    job = ConvertJob(job_id=job_id, queue=asyncio.Queue(), loop=loop)
    jobs[job_id] = job

    thread = threading.Thread(
        target=_run_convert,
        args=(job, input_path, target_format),
        daemon=True,
    )
    thread.start()
    return job_id


def start_compress_job(
    input_path: Path,
    crf: int,
    loop: asyncio.AbstractEventLoop,
) -> str:
    job_id = uuid.uuid4().hex
    job = ConvertJob(job_id=job_id, queue=asyncio.Queue(), loop=loop)
    jobs[job_id] = job

    thread = threading.Thread(
        target=_run_compress,
        args=(job, input_path, crf),
        daemon=True,
    )
    thread.start()
    return job_id


def cancel_job(job_id: str) -> bool:
    job = jobs.get(job_id)
    if job is None:
        return False
    job.cancel_event.set()
    return True


_AUDIO_FORMATS = {"mp3", "wav", "m4a", "aac", "flac", "ogg"}


def _run_ffmpeg(job: ConvertJob, cmd: list[str], output_path: Path, original_size: int) -> None:
    import subprocess

    process = subprocess.Popen(
        cmd,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1,
    )

    duration: Optional[float] = None
    try:
        for line in process.stdout:
            if job.cancel_event.is_set():
                process.terminate()
                _emit(job, {"status": "cancelled"})
                output_path.unlink(missing_ok=True)
                return

            if duration is None:
                dmatch = _DURATION_RE.search(line)
                if dmatch:
                    duration = _parse_timestamp(dmatch)

            tmatch = _TIME_RE.search(line)
            if tmatch and duration:
                current = _parse_timestamp(tmatch)
                progress = min(current / duration, 0.99)
                _emit(job, {"status": "converting", "progress": progress})

        process.wait()
    except Exception as exc:
        _emit(job, {"status": "error", "error": str(exc)})
        output_path.unlink(missing_ok=True)
        return

    if process.returncode != 0 or not output_path.exists():
        _emit(job, {"status": "error", "error": "Conversion failed"})
        output_path.unlink(missing_ok=True)
        return

    new_size = output_path.stat().st_size
    _emit(job, {
        "status": "finished",
        "filename": output_path.name,
        "original_size": original_size,
        "new_size": new_size,
    })


def _run_convert(job: ConvertJob, input_path: Path, target_format: str) -> None:
    short_id = uuid.uuid4().hex[:8]
    output_path = DOWNLOAD_DIR / f"converted-{short_id}.{target_format}"
    original_size = input_path.stat().st_size if input_path.exists() else 0

    cmd = ["ffmpeg", "-y", "-i", str(input_path)]
    if target_format in _AUDIO_FORMATS:
        cmd += ["-vn"]
    cmd += [str(output_path)]

    try:
        _run_ffmpeg(job, cmd, output_path, original_size)
    finally:
        input_path.unlink(missing_ok=True)


def _run_compress(job: ConvertJob, input_path: Path, crf: int) -> None:
    short_id = uuid.uuid4().hex[:8]
    suffix = input_path.suffix or ".mp4"
    output_path = DOWNLOAD_DIR / f"compressed-{short_id}{suffix}"
    original_size = input_path.stat().st_size if input_path.exists() else 0

    cmd = [
        "ffmpeg", "-y", "-i", str(input_path),
        "-vcodec", "libx264", "-crf", str(crf),
        "-preset", "medium",
        "-acodec", "aac", "-b:a", "128k",
        str(output_path),
    ]

    try:
        _run_ffmpeg(job, cmd, output_path, original_size)
    finally:
        input_path.unlink(missing_ok=True)