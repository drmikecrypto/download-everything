"""Download Everything API — universal media extraction powered by yt-dlp."""

from __future__ import annotations

import glob
import os
import re
import tempfile
from typing import AsyncIterator

import httpx
import yt_dlp
from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse

from config import settings
from extractor import analyze_url, direct_stream_target, prepare_download
from models import AnalyzeRequest, AnalyzeResponse

app = FastAPI(
    title="Download Everything API",
    description="Analyze and download media from 1,800+ websites. Built by drmikecrypto.",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


def _safe_filename(title: str | None, ext: str) -> str:
    base = title or "download"
    safe = re.sub(r"[^\w\s\-_.]", "", base, flags=re.UNICODE).strip()[:80]
    safe = safe or "download"
    return f"{safe}.{ext.lstrip('.')}"


def _media_type(ext: str) -> str:
    if ext in ("mp4", "webm", "mkv", "mov"):
        return f"video/{ext}"
    if ext in ("mp3", "m4a", "opus", "aac", "ogg"):
        return f"audio/{ext}"
    if ext in ("jpg", "jpeg", "png", "webp", "gif"):
        return f"image/{ext}"
    return "application/octet-stream"


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "service": "download-everything"}


@app.post("/analyze", response_model=AnalyzeResponse)
async def analyze(body: AnalyzeRequest) -> AnalyzeResponse:
    result = analyze_url(str(body.url))
    if result.error and not result.formats:
        raise HTTPException(status_code=422, detail=result.error)
    return result


async def _stream_http_url(
    source_url: str,
    headers: dict[str, str],
    filename: str,
    ext: str,
) -> StreamingResponse:
    client = httpx.AsyncClient(timeout=httpx.Timeout(120.0, connect=30.0), follow_redirects=True)

    async def body() -> AsyncIterator[bytes]:
        try:
            async with client.stream("GET", source_url, headers=headers) as response:
                response.raise_for_status()
                async for chunk in response.aiter_bytes(1024 * 256):
                    yield chunk
        finally:
            await client.aclose()

    return StreamingResponse(
        body(),
        media_type=_media_type(ext),
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@app.get("/download")
async def download(
    url: str = Query(..., description="Media URL to download"),
    format_id: str = Query("best", description="Format ID from /analyze response"),
    filename: str | None = Query(None, description="Optional download filename"),
) -> StreamingResponse:
    try:
        direct = direct_stream_target(url, format_id)
        if direct is not None:
            source_url, headers, ext, media_title = direct
            out_name = filename or _safe_filename(media_title, ext)
            return await _stream_http_url(source_url, headers, out_name, ext)

        opts, info, ext_hint = prepare_download(url, format_id)
        title = info.get("title") or "download"
        out_name = filename or _safe_filename(title, ext_hint)

        with tempfile.NamedTemporaryFile(suffix=".tmp", delete=False) as tmp:
            tmp_path = tmp.name

        download_opts = {
            **opts,
            "outtmpl": tmp_path + ".%(ext)s",
        }

        with yt_dlp.YoutubeDL(download_opts) as ydl:
            result = ydl.extract_info(url, download=True)
            if result is None:
                raise HTTPException(status_code=422, detail="Download failed.")

            ext = result.get("ext") or ext_hint
            if not filename:
                out_name = _safe_filename(result.get("title") or title, ext)

        files = glob.glob(tmp_path + "*")
        if not files:
            raise HTTPException(status_code=500, detail="Download produced no file.")

        file_path = files[0]
        file_size = os.path.getsize(file_path)

        def iter_file() -> AsyncIterator[bytes]:
            try:
                with open(file_path, "rb") as f:
                    while chunk := f.read(1024 * 256):
                        yield chunk
            finally:
                for path in glob.glob(tmp_path + "*"):
                    try:
                        os.remove(path)
                    except OSError:
                        pass

        return StreamingResponse(
            iter_file(),
            media_type=_media_type(ext),
            headers={
                "Content-Disposition": f'attachment; filename="{out_name}"',
                "Content-Length": str(file_size),
            },
        )
    except yt_dlp.utils.DownloadError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except httpx.HTTPError as exc:
        raise HTTPException(status_code=422, detail=f"Stream failed: {exc}") from exc
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc
