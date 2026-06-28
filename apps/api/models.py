from pydantic import BaseModel, Field, HttpUrl


class AnalyzeRequest(BaseModel):
    url: HttpUrl


class MediaFormat(BaseModel):
    format_id: str
    label: str
    ext: str
    resolution: str | None = None
    fps: float | None = None
    vcodec: str | None = None
    acodec: str | None = None
    filesize: int | None = None
    filesize_approx: int | None = None
    tbr: float | None = None
    is_video: bool = False
    is_audio: bool = False
    is_image: bool = False


class AnalyzeResponse(BaseModel):
    url: str
    title: str | None = None
    description: str | None = None
    thumbnail: str | None = None
    uploader: str | None = None
    duration: float | None = None
    platform: str | None = None
    extractor: str | None = None
    formats: list[MediaFormat] = Field(default_factory=list)
    error: str | None = None
