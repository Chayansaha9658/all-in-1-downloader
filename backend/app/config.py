from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent
DOWNLOAD_DIR = BASE_DIR / "downloads"
DOWNLOAD_DIR.mkdir(exist_ok=True)

# Tighten this before shipping the Flutter app to production.
ALLOWED_ORIGINS = ["*"]


def clear_download_dir() -> None:
    """Removes any leftover files in the downloads folder (from crashed,
    cancelled, or failed jobs from a previous run). Successful downloads are
    normally deleted right after being served to the app, but this catches
    anything that slipped through."""
    for item in DOWNLOAD_DIR.iterdir():
        if item.name == ".gitkeep":
            continue
        if item.is_file():
            item.unlink(missing_ok=True)