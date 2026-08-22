import re
import urllib.request
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin

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
        # Some sites (or a network hop in between) reset the connection on
        # long single-stream transfers -- small audio files finish before
        # that happens, but large video files don't. Downloading in chunks
        # via Range requests means a mid-transfer reset only has to retry
        # the current chunk, not restart the whole file.
        "http_chunk_size": 10 * 1024 * 1024,
        "fragment_retries": 10,
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


def _fetch_page_html(url: str, timeout: int = 15) -> str:
    """Plain HTTP GET of the page source, reused by every scraping-based
    fallback below so the page is only downloaded once per attempt."""
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        raw = response.read()
    charset = response.headers.get_content_charset() or "utf-8"
    return raw.decode(charset, errors="ignore")


def _scrape_og_video_url(html: str) -> Optional[str]:
    """Looks for the og:video / twitter:player meta tag many sites set for
    link-preview cards -- when present it's a direct link straight to the
    video file, no JS rendering needed."""
    for prop in ("og:video:url", "og:video", "twitter:player:stream"):
        pattern = (
            rf'<meta[^>]+(?:property|name)=["\']?{re.escape(prop)}["\']?[^>]+content=["\']([^"\']+)'
        )
        match = re.search(pattern, html, re.IGNORECASE)
        if match:
            return match.group(1)
    return None


def _scrape_media_url(html: str) -> Optional[str]:
    """Looks for a raw .m3u8 (HLS) or .mp4 link sitting in the page source
    or an inline <script> block -- common with simple/older video players
    that don't bother obfuscating the source."""
    m = re.search(r'https?://[^\s"\'<>\\]+\.m3u8[^\s"\'<>\\]*', html)
    if m:
        return m.group(0)
    m = re.search(r'https?://[^\s"\'<>\\]+\.mp4[^\s"\'<>\\]*', html)
    return m.group(0) if m else None


def _scrape_iframe_src(html: str) -> Optional[str]:
    """Some sites don't host the player themselves -- they embed a third
    party player (streamtape/dood/mixdrop-style) via <iframe>. Returns that
    iframe's src so the caller can resolve it as its own page."""
    match = re.search(r'<iframe[^>]+src=["\']([^"\']+)', html, re.IGNORECASE)
    return match.group(1) if match else None


def extract_via_fallback_chain(url: str, download: bool, extra_opts: Optional[dict] = None):
    """Tries independent extraction strategies in order, stopping at the
    first that works. Each strategy gets exactly one attempt here -- the
    short internal retry ladder inside run_generic (unsupported URL / auth /
    patient timeout) still applies within a strategy, but the chain itself
    never re-tries a strategy that already failed, so a genuinely unsupported
    URL fails in a handful of attempts instead of stalling through every
    strategy multiple times.
    """
    errors: list[str] = []

    # 1) yt-dlp's own extractor (dedicated site extractor, or generic HTML
    # extractor as yt-dlp's own fallback -- see run_generic).
    try:
        return run_generic(url, download, extra_opts)
    except Exception as exc:
        errors.append(f"yt-dlp: {exc}")

    try:
        html = _fetch_page_html(url)
    except Exception as exc:
        errors.append(f"page fetch: {exc}")
        return _raise_chain_failure(errors)

    # 2) Open Graph / Twitter Player meta tag -- direct file link, no JS
    # rendering required.
    og_url = _scrape_og_video_url(html)
    if og_url:
        try:
            return run_generic(urljoin(url, og_url), download, extra_opts)
        except Exception as exc:
            errors.append(f"og:video: {exc}")

    # 3) A raw .m3u8/.mp4 link sitting directly in the page source.
    media_url = _scrape_media_url(html)
    if media_url:
        try:
            return run_generic(media_url, download, extra_opts)
        except Exception as exc:
            errors.append(f"media scrape: {exc}")

    # 4) The page embeds a third-party player via <iframe> -- resolve that
    # page instead (one level deep only, to keep this bounded).
    iframe_src = _scrape_iframe_src(html)
    if iframe_src:
        try:
            return run_generic(urljoin(url, iframe_src), download, extra_opts)
        except Exception as exc:
            errors.append(f"iframe: {exc}")

    return _raise_chain_failure(errors)


def _raise_chain_failure(errors: list[str]):
    raise Exception("Unsupported URL -- every fallback failed: " + " | ".join(errors))


def extract_info_with_retry(url: str, download: bool, extra_opts: Optional[dict] = None):
    if not is_youtube_url(url):
        return extract_via_fallback_chain(url, download, extra_opts)

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