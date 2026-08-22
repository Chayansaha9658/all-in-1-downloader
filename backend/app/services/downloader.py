import re
from pathlib import Path
from typing import Optional

import yt_dlp

from app.models.schemas import FormatOption, VideoInfo

# Used when listing available formats/resolutions -- android-family clients expose
# the widest range of quality options without needing cookies/auth.
INFO_PLAYER_CLIENTS = ["android_vr", "android", "tv", "web"]

# Used when actually downloading -- "web" avoids a known false-positive "DRM protected"
# error that the android/android_vr clients raise for some otherwise-normal formats.
DOWNLOAD_PLAYER_CLIENTS = ["web", "tv", "android", "android_vr"]

# Kept for backward compatibility with any other callers.
PLAYER_CLIENTS = INFO_PLAYER_CLIENTS

# If present, cookies exported from a *secondary/throwaway* account are used
# for the retry instead of pulling from the live Chrome session -- keeps the
# person's main account out of it. Export via a "cookies.txt" browser
# extension while logged into the throwaway account, Netscape format, and
# save it to this exact path.
COOKIES_FILE = Path(__file__).resolve().parents[2] / "cookies" / "cookies.txt"

# Substrings that mean "this needs a logged-in session" across the sites
# yt-dlp hits here (Instagram phrases this differently from a plain 403).
AUTH_REQUIRED_MARKERS = (
    "403",
    "Forbidden",
    "429",
    "Sign in",
    "consent",
    "empty media response",
    "login required",
    "Requested content is not available",
    "rate-limit reached",
)


USER_AGENT = (
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
)


def base_opts() -> dict:
    return {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "socket_timeout": 20,
        "http_headers": {"User-Agent": USER_AGENT},
        "force_ipv4": True,
        "retries": 3,
    }


def _apply_cookie_source(opts: dict) -> None:
    """Prefers a static cookies.txt (secondary account) over the live
    Chrome session, so retries never touch the person's main account."""
    if COOKIES_FILE.exists():
        opts["cookiefile"] = str(COOKIES_FILE)
    else:
        opts["cookiesfrombrowser"] = ("chrome",)


def is_youtube_url(url: str) -> bool:
    url = url.lower()
    return "youtube.com" in url or "youtu.be" in url


def run_generic(url: str, download: bool, extra_opts: Optional[dict] = None):
    """Runs yt-dlp on a non-YouTube URL, picking the right strategy based on
    what the first attempt's failure actually looks like, instead of blindly
    retrying every strategy for every URL:
      - "Unsupported URL" (no dedicated extractor)  -> force the generic HTML extractor
      - auth/login-required markers (403, empty media response, etc.) -> retry with cookies
      - anything else (timeout, connection reset)    -> retry with a longer timeout
    """

    def _try(opts: dict):
        with yt_dlp.YoutubeDL(opts) as ydl:
            return ydl.extract_info(url, download=download)

    opts = base_opts()
    if extra_opts:
        opts.update(extra_opts)

    try:
        return _try(opts)
    except Exception as exc:
        message = str(exc)

    if "Unsupported URL" in message:
        forced = base_opts()
        forced["force_generic_extractor"] = True
        if extra_opts:
            forced.update(extra_opts)
        return _try(forced)

    if any(marker in message for marker in AUTH_REQUIRED_MARKERS):
        with_cookies = base_opts()
        _apply_cookie_source(with_cookies)
        if extra_opts:
            with_cookies.update(extra_opts)
        return _try(with_cookies)

    # Likely a transient network issue (timeout, connection reset). Retrying
    # with the exact same short timeout rarely helps a genuinely slow or
    # rate-limiting site -- give it more room and more attempts instead.
    patient = base_opts()
    patient["socket_timeout"] = 45
    patient["retries"] = 6
    if extra_opts:
        patient.update(extra_opts)
    return _try(patient)

    # Likely a transient network issue (timeout, connection reset) -- one retry.
    return _try(opts)


def sanitize_filename(title: str, max_length: int = 80) -> str:
    cleaned = re.sub(r'[\\/:*?"<>|]', "", title or "")
    cleaned = re.sub(r"\s+", " ", cleaned).strip()
    return cleaned[:max_length] if cleaned else "download"


def extract_info_with_retry(url: str, download: bool, extra_opts: Optional[dict] = None):
    if not is_youtube_url(url):
        return run_generic(url, download, extra_opts)

    last_exc: Optional[Exception] = None
    for client in INFO_PLAYER_CLIENTS:
        opts = base_opts()
        opts["extractor_args"] = {"youtube": {"player_client": [client]}}
        if extra_opts:
            opts.update(extra_opts)
        try:
            with yt_dlp.YoutubeDL(opts) as ydl:
                return ydl.extract_info(url, download=download)
        except yt_dlp.utils.DownloadError as exc:
            last_exc = exc
            continue
    raise last_exc


def fetch_info(url: str) -> VideoInfo:
    raw = extract_info_with_retry(url, download=False)

    formats = [
        FormatOption(
            format_id=f["format_id"],
            ext=f.get("ext", ""),
            resolution=f.get("resolution") or f.get("format_note"),
            fps=f.get("fps"),
            filesize=f.get("filesize") or f.get("filesize_approx"),
            vcodec=f.get("vcodec"),
            acodec=f.get("acodec"),
            note=f.get("format_note"),
        )
        for f in raw.get("formats", [])
        if f.get("vcodec") != "none" or f.get("acodec") != "none"
    ]

    return VideoInfo(
        title=raw.get("title", "Untitled"),
        thumbnail=raw.get("thumbnail"),
        duration=raw.get("duration"),
        uploader=raw.get("uploader"),
        extractor=raw.get("extractor", "generic"),
        formats=formats,
    )