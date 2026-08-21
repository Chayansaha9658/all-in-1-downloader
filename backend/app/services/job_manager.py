import asyncio
import re
import threading
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import yt_dlp

from app.config import DOWNLOAD_DIR
from app.services.downloader import (
    DOWNLOAD_PLAYER_CLIENTS,
    base_opts,
    is_youtube_url,
    run_generic,
    sanitize_filename,
)

_ANSI_RE = re.compile(r"\x1b\[[0-9;]*m")


def _clean(text: str) -> str:
    return _ANSI_RE.sub("", text or "").strip()


@dataclass
class DownloadJob:
    job_id: str
    queue: "asyncio.Queue[dict]"
    loop: asyncio.AbstractEventLoop = field(repr=False)
    cancel_event: threading.Event = field(default_factory=threading.Event)


jobs: dict[str, DownloadJob] = {}


def _emit(job: DownloadJob, event: dict) -> None:
    job.loop.call_soon_threadsafe(job.queue.put_nowait, event)


def start_download_job(
    url: str,
    format_id: Optional[str],
    audio_only: bool,
    audio_format: str,
    loop: asyncio.AbstractEventLoop,
) -> str:
    job_id = uuid.uuid4().hex
    job = DownloadJob(job_id=job_id, queue=asyncio.Queue(), loop=loop)
    jobs[job_id] = job

    thread = threading.Thread(
        target=_run_download,
        args=(job, url, format_id, audio_only, audio_format),
        daemon=True,
    )
    thread.start()
    return job_id


def cancel_download_job(job_id: str) -> bool:
    job = jobs.get(job_id)
    if job is None:
        return False
    job.cancel_event.set()
    return True


def _resolve_title(job: DownloadJob, url: str) -> Optional[str]:
    if not is_youtube_url(url):
        try:
            raw = run_generic(url, download=False)
            return raw.get("title", "Untitled")
        except Exception as exc:
            _emit(job, {"status": "error", "error": _clean(str(exc))})
            return None

    last_exc: Optional[Exception] = None
    for client in DOWNLOAD_PLAYER_CLIENTS:
        if job.cancel_event.is_set():
            _emit(job, {"status": "cancelled"})
            return None
        opts = base_opts()
        opts["extractor_args"] = {"youtube": {"player_client": [client]}}
        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                raw = ydl.extract_info(url, download=False)
            return raw.get("title", "Untitled")
        except yt_dlp.utils.DownloadError as exc:
            last_exc = exc
            continue
    _emit(job, {"status": "error", "error": _clean(str(last_exc)) if last_exc else "Could not fetch video info"})
    return None


def _attempt_download_pass(job: DownloadJob, url: str, out_template: str, audio_only: bool, audio_format: str, format_id: Optional[str]):
    """Try every player client once.
    Returns (final_path, None) on success, (None, None) if cancelled,
    or (None, last_exception) if the whole pass failed.
    """

    last_emit_time = [0.0]

    def progress_hook(d: dict) -> None:
        if job.cancel_event.is_set():
            raise yt_dlp.utils.DownloadCancelled("Cancelled by user")
        if d["status"] == "downloading":
            now = time.monotonic()
            if now - last_emit_time[0] < 0.4:
                return
            last_emit_time[0] = now
            _emit(job, {
                "status": "downloading",
                "downloaded_bytes": d.get("downloaded_bytes", 0),
                "total_bytes": d.get("total_bytes") or d.get("total_bytes_estimate"),
                "speed": d.get("speed"),
                "eta": d.get("eta"),
            })
        elif d["status"] == "finished":
            _emit(job, {"status": "merging"})

    def _format_for(audio_only: bool, format_id: Optional[str]) -> dict:
        opts: dict = {}
        if audio_only:
            opts["format"] = "bestaudio/best"
            opts["postprocessors"] = [
                {
                    "key": "FFmpegExtractAudio",
                    "preferredcodec": audio_format,
                    "preferredquality": "192",
                }
            ]
        else:
            if format_id:
                # format_id here is a target height (e.g. "1080"), not a literal itag --
                # this lets each client pick its own best-available format at or below
                # that height instead of requiring an exact itag that may not exist
                # under every client's extraction.
                opts["format"] = (
                    f"bestvideo[height<={format_id}]+bestaudio/best[height<={format_id}]"
                    f"/best[height<={format_id}]/bestvideo+bestaudio/best"
                )
            else:
                opts["format"] = "bestvideo+bestaudio/best"
            opts["merge_output_format"] = "mp4"
        return opts

    def _run_one(opts: dict):
        with yt_dlp.YoutubeDL(opts) as ydl:
            raw = ydl.extract_info(url, download=True)
            requested = raw.get("requested_downloads") or []
            if requested and requested[0].get("filepath"):
                return Path(requested[0]["filepath"])
            path = Path(ydl.prepare_filename(raw))
            if audio_only:
                path = path.with_suffix(f".{audio_format}")
            return path

    if not is_youtube_url(url):
        # Non-YouTube sites don't need YouTube player_client rotation --
        # run_generic picks the right retry strategy based on the failure.
        opts_extra: dict = {"outtmpl": out_template, "progress_hooks": [progress_hook]}
        opts_extra.update(_format_for(audio_only, format_id))
        try:
            raw = run_generic(url, download=True, extra_opts=opts_extra)
            requested = raw.get("requested_downloads") or []
            if requested and requested[0].get("filepath"):
                return Path(requested[0]["filepath"]), None
            with yt_dlp.YoutubeDL(base_opts()) as ydl:
                path = Path(ydl.prepare_filename(raw))
            if audio_only:
                path = path.with_suffix(f".{audio_format}")
            return path, None
        except yt_dlp.utils.DownloadCancelled:
            return None, None
        except Exception as exc:
            return None, exc

    last_exc: Optional[Exception] = None
    for client in DOWNLOAD_PLAYER_CLIENTS:
        if job.cancel_event.is_set():
            return None, None

        opts = base_opts()
        opts["outtmpl"] = out_template
        opts["extractor_args"] = {"youtube": {"player_client": [client]}}
        opts["progress_hooks"] = [progress_hook]
        opts.update(_format_for(audio_only, format_id))

        try:
            return _run_one(opts), None
        except yt_dlp.utils.DownloadCancelled:
            return None, None
        except yt_dlp.utils.DownloadError as exc:
            last_exc = exc
            _emit(job, {"status": "retrying", "player_client": client})
            continue
        except Exception as exc:
            return None, exc

    return None, last_exc


def _cleanup_partial_files(short_id: str) -> None:
    """Removes any leftover file(s) for this job (e.g. a partially downloaded
    file left behind after a cancel or failure) so nothing lingers on disk."""
    for leftover in DOWNLOAD_DIR.glob(f"*-{short_id}.*"):
        leftover.unlink(missing_ok=True)


def _run_download(
    job: DownloadJob,
    url: str,
    format_id: Optional[str],
    audio_only: bool,
    audio_format: str,
) -> None:
    title = _resolve_title(job, url)
    if title is None:
        return

    short_id = uuid.uuid4().hex[:8]
    out_template = str(DOWNLOAD_DIR / f"{sanitize_filename(title)}-{short_id}.%(ext)s")

    # First (and only) full pass across all player clients -- each client is already
    # a fallback for the others, so a second full pass just delays a real failure.
    final_path, last_exc = _attempt_download_pass(job, url, out_template, audio_only, audio_format, format_id)

    if job.cancel_event.is_set():
        _cleanup_partial_files(short_id)
        _emit(job, {"status": "cancelled"})
        return

    if final_path is None:
        _cleanup_partial_files(short_id)
        _emit(job, {"status": "error", "error": _clean(str(last_exc)) if last_exc else "Download failed after retries"})
        return

    _emit(job, {"status": "finished", "filename": final_path.name, "title": title})