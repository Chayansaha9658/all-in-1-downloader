# All in 1 Downloader

A cross-platform media downloader built with Flutter and Python (FastAPI), supporting YouTube, Facebook, Instagram, and 1000+ other sites via a multi-strategy extraction pipeline.

## Features

- **Video & audio downloads** with resolution selection, powered by `yt-dlp`
- **Multi-layer extractor fallback chain** — when a site isn't directly supported, the backend automatically falls back through: dedicated extractor → generic HTML extractor → Open Graph meta-tag scraping → HLS/media file regex scraping → iframe embed resolution → `gallery-dl`
- **In-app browser with media sniffing** — a WebView-based browser that intercepts network requests and DOM changes to detect direct media links on pages that don't expose them plainly, then feeds them into the download pipeline
- **On-device backend hosting** — the FastAPI backend can run locally on desktop or directly on an Android phone via Termux, with a guided in-app setup wizard that automates environment provisioning (Python, git, ffmpeg, virtualenv) and permission handling
- **Live progress via Server-Sent Events** for downloads and format conversion
- **Format conversion & compression** using `ffmpeg` (video/audio transcoding, CRF-based compression)
- **Background download management** with an overlay bubble for tracking downloads while using other apps
- **Light/dark neomorphic UI** with a custom theme system

## Architecture

**Frontend** — Flutter (Android, macOS)
- `webview_flutter` for the in-app browser with JavaScript-injected network/DOM sniffing
- Platform channels (Kotlin) for the overlay bubble and Termux RUN_COMMAND integration
- SSE client for real-time download progress

**Backend** — Python, FastAPI
- `yt-dlp` for extraction, with player-client rotation (YouTube) and a chained fallback strategy (generic sites) to maximize site coverage
- Threaded job manager with cancellation support for concurrent downloads
- `ffmpeg` subprocess pipeline for conversion/compression with progress parsing

## Tech Stack

`Flutter` `Dart` `Python` `FastAPI` `yt-dlp` `ffmpeg` `WebView` `Kotlin` `Termux` `Server-Sent Events`

## Setup

**Backend**
```bash
cd backend
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000