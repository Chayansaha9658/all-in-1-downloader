from typing import List, Literal, Optional

from pydantic import BaseModel, HttpUrl


class InfoRequest(BaseModel):
    url: HttpUrl


class FormatOption(BaseModel):
    format_id: str
    ext: str
    resolution: Optional[str] = None
    fps: Optional[float] = None
    filesize: Optional[int] = None
    vcodec: Optional[str] = None
    acodec: Optional[str] = None
    note: Optional[str] = None


class VideoInfo(BaseModel):
    title: str
    thumbnail: Optional[str] = None
    duration: Optional[float] = None
    uploader: Optional[str] = None
    extractor: str
    formats: List[FormatOption]


class DownloadRequest(BaseModel):
    url: HttpUrl
    format_id: Optional[str] = None
    audio_only: bool = False
    audio_format: Literal["mp3", "m4a"] = "mp3"
    title: Optional[str] = None


class StartDownloadResponse(BaseModel):
    job_id: str
