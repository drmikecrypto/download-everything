"""yt-dlp wrapper — analyzes URLs and normalizes format metadata."""

from __future__ import annotations

import re
from typing import Any

import yt_dlp

from config import settings
from models import AnalyzeResponse, MediaFormat

PLATFORM_PATTERNS: list[tuple[str, re.Pattern[str]]] = [
    ("Instagram", re.compile(r"(instagram\.com|instagr\.am)", re.I)),
    ("TikTok", re.compile(r"(tiktok\.com|vm\.tiktok\.com)", re.I)),
    ("YouTube", re.compile(r"(youtube\.com|youtu\.be)", re.I)),
    ("X", re.compile(r"(twitter\.com|x\.com)", re.I)),
]

_SKIP_EXT = frozenset({"mhtml", "sb0", "sb1", "sb2"})
_IMAGE_EXT = frozenset({"jpg", "jpeg", "png", "webp", "gif"})
_FAKE_PAGE_VIDEO = re.compile(r"/videos/[0-9a-f]{6,64}$", re.I)


def detect_platform(url: str) -> str | None:
    for name, pattern in PLATFORM_PATTERNS:
        if pattern.search(url):
            return name
    return None


def _base_opts() -> dict[str, Any]:
    return {
        "quiet": True,
        "no_warnings": True,
        "noplaylist": True,
        "socket_timeout": settings.max_analyze_timeout,
        "http_headers": {"User-Agent": settings.user_agent},
    }


def _human_size(size: int | None) -> str:
    if not size:
        return ""
    units = ["B", "KB", "MB", "GB"]
    value = float(size)
    for unit in units:
        if value < 1024 or unit == units[-1]:
            return f"{value:.1f} {unit}"
        value /= 1024
    return ""


def _format_label(fmt: dict[str, Any]) -> str:
    parts: list[str] = []
    if fmt.get("resolution") and fmt["resolution"] != "audio only":
        parts.append(str(fmt["resolution"]))
    elif fmt.get("height"):
        parts.append(f"{fmt['height']}p")
    if fmt.get("fps"):
        parts.append(f"{int(fmt['fps'])}fps")
    if fmt.get("ext"):
        parts.append(str(fmt["ext"]).upper())
    if fmt.get("vcodec") and fmt["vcodec"] != "none":
        vcodec = str(fmt["vcodec"]).split(".")[0]
        if vcodec not in ("none", "unknown"):
            parts.append(vcodec)
    if fmt.get("acodec") and fmt["acodec"] != "none" and not fmt.get("height"):
        parts.append("audio")
    size = fmt.get("filesize") or fmt.get("filesize_approx")
    if size:
        parts.append(_human_size(int(size)))
    if fmt.get("format_note"):
        parts.append(str(fmt["format_note"]))
    return " · ".join(parts) if parts else str(fmt.get("format_id", "unknown"))


def _is_storyboard(fmt: dict[str, Any]) -> bool:
    note = str(fmt.get("format_note") or "").lower()
    return "storyboard" in note or str(fmt.get("format_id", "")).startswith("sb")


def _classify_format(fmt: dict[str, Any]) -> tuple[bool, bool, bool]:
    vcodec = fmt.get("vcodec")
    acodec = fmt.get("acodec")
    ext = str(fmt.get("ext") or "").lower()

    is_video = vcodec not in (None, "none")
    is_audio = acodec not in (None, "none") and not is_video
    is_image = ext in _IMAGE_EXT

    if not is_video and not is_audio and fmt.get("resolution") == "audio only":
        is_audio = True

    return is_video, is_audio, is_image


def _is_fake_video_stub(fmt: dict[str, Any]) -> bool:
    """Some extractors list page URLs as direct MP4 links (always 404)."""
    url = str(fmt.get("url") or "")
    protocol = str(fmt.get("protocol") or "").lower()
    note = str(fmt.get("format_note") or "").lower()

    if "untested" in note:
        return True
    if "m3u8" in protocol or "dash" in protocol:
        return False
    if _FAKE_PAGE_VIDEO.search(url):
        return True
    if protocol == "https" and "/videos/" in url and not any(
        token in url.lower() for token in ("xhcdn", ".mp4", ".m3u8", "cdn", "media")
    ):
        return True
    return False


def _is_downloadable_format(fmt: dict[str, Any]) -> bool:
    ext = str(fmt.get("ext") or "").lower()
    if ext in _SKIP_EXT or _is_storyboard(fmt):
        return False
    if fmt.get("url") is None and fmt.get("manifest_url") is None:
        return False
    if _is_fake_video_stub(fmt):
        return False

    is_video, is_audio, is_image = _classify_format(fmt)
    return is_video or is_audio or is_image


def _normalize_formats(raw_formats: list[dict[str, Any]] | None) -> list[MediaFormat]:
    if not raw_formats:
        return []

    seen: set[str] = set()
    result: list[MediaFormat] = []

    for fmt in raw_formats:
        format_id = str(fmt.get("format_id", ""))
        if not format_id or format_id in seen:
            continue
        if not _is_downloadable_format(fmt):
            continue

        vcodec = fmt.get("vcodec")
        acodec = fmt.get("acodec")
        is_video, is_audio, is_image = _classify_format(fmt)

        seen.add(format_id)
        result.append(
            MediaFormat(
                format_id=format_id,
                label=_format_label(fmt),
                ext=str(fmt.get("ext") or "mp4"),
                resolution=fmt.get("resolution"),
                fps=fmt.get("fps"),
                vcodec=None if vcodec == "none" else vcodec,
                acodec=None if acodec == "none" else acodec,
                filesize=fmt.get("filesize"),
                filesize_approx=fmt.get("filesize_approx"),
                tbr=fmt.get("tbr"),
                is_video=is_video,
                is_audio=is_audio,
                is_image=is_image,
            )
        )

    result.sort(
        key=lambda f: (
            0 if f.is_video else 1 if f.is_audio else 2,
            -(f.filesize or f.filesize_approx or 0),
            f.label,
        )
    )
    return _dedupe_format_variants(result)


def _dedupe_format_variants(formats: list[MediaFormat]) -> list[MediaFormat]:
    """Keep one entry per quality (e.g. hls-1064-0 vs hls-1064-1)."""
    best: dict[str, MediaFormat] = {}
    for fmt in formats:
        base = re.sub(r"-\d+$", "", fmt.format_id)
        key = f"{base}|{fmt.resolution or ''}|{fmt.ext}"
        current = best.get(key)
        if current is None:
            best[key] = fmt
            continue
        if fmt.acodec and not current.acodec:
            best[key] = fmt
    return list(best.values())


def _extract_info(url: str) -> dict[str, Any]:
    opts = {**_base_opts(), "skip_download": True}
    with yt_dlp.YoutubeDL(opts) as ydl:
        info = ydl.extract_info(url, download=False)
    if info is None:
        raise yt_dlp.utils.DownloadError("Could not extract media from this URL.")
    if info.get("_type") == "playlist" and info.get("entries"):
        info = info["entries"][0] or info
    return info


def _find_format(info: dict[str, Any], format_id: str) -> dict[str, Any] | None:
    for fmt in info.get("formats") or []:
        if str(fmt.get("format_id")) == format_id:
            return fmt
    return None


def _parse_height_from_format_id(format_id: str) -> int | None:
    match = re.search(r"(\d{3,4})p", format_id, re.I)
    return int(match.group(1)) if match else None


def _resolve_format_id(info: dict[str, Any], format_id: str) -> str:
    """Map legacy/broken format IDs to a working stream (e.g. h264-720p-1 → h264-720p)."""
    if format_id == "best":
        return format_id

    fmt = _find_format(info, format_id)
    if fmt is not None and not _is_fake_video_stub(fmt):
        return format_id

    # Old yt-dlp builds used h264-720p-0 / h264-720p-1 — strip the trailing variant index.
    base_id = re.sub(r"-\d+$", "", format_id)
    if base_id != format_id:
        base_fmt = _find_format(info, base_id)
        if base_fmt is not None and not _is_fake_video_stub(base_fmt):
            return base_id

    target_height = _parse_height_from_format_id(format_id)
    candidates: list[dict[str, Any]] = []

    for candidate in info.get("formats") or []:
        if not _is_downloadable_format(candidate):
            continue
        protocol = str(candidate.get("protocol") or "").lower()
        if "m3u8" not in protocol and "dash" not in protocol:
            continue
        if target_height and candidate.get("height") not in (target_height, None):
            if candidate.get("height") != target_height:
                continue
        candidates.append(candidate)

    if not candidates and target_height:
        for candidate in info.get("formats") or []:
            if _is_downloadable_format(candidate) and candidate.get("height") == target_height:
                candidates.append(candidate)

    if not candidates:
        return format_id

    def score(item: dict[str, Any]) -> tuple[int, int, float]:
        has_audio = 1 if item.get("acodec") not in (None, "none", "unknown") else 0
        is_hls = 1 if "m3u8" in str(item.get("protocol") or "") else 0
        bitrate = float(item.get("tbr") or 0)
        return (has_audio, is_hls, bitrate)

    best = max(candidates, key=score)
    return str(best["format_id"])


def _format_selector(info: dict[str, Any], format_id: str) -> str:
    if format_id == "best":
        return "bestvideo*+bestaudio/best"

    resolved = _resolve_format_id(info, format_id)
    fmt = _find_format(info, resolved)
    if fmt is None:
        return resolved

    is_video, is_audio, _ = _classify_format(fmt)
    protocol = str(fmt.get("protocol") or "").lower()

    if "m3u8" in protocol or "dash" in protocol:
        return resolved
    if is_video and not is_audio:
        return f"{resolved}+bestaudio/best"
    if is_audio and not is_video:
        return resolved
    return resolved


def _needs_merge(fmt: dict[str, Any] | None) -> bool:
    if fmt is None:
        return True
    is_video, is_audio, _ = _classify_format(fmt)
    return is_video and not is_audio


def _page_headers(info: dict[str, Any], page_url: str) -> dict[str, str]:
    referer = info.get("webpage_url") or info.get("original_url") or page_url
    return {
        "User-Agent": settings.user_agent,
        "Referer": referer,
    }


def analyze_url(url: str) -> AnalyzeResponse:
    try:
        info = _extract_info(url)
        formats = _normalize_formats(info.get("formats"))

        if not formats and info.get("url"):
            formats = [
                MediaFormat(
                    format_id="best",
                    label="Best available",
                    ext=str(info.get("ext") or "mp4"),
                    is_video=True,
                )
            ]

        return AnalyzeResponse(
            url=url,
            title=info.get("title") or info.get("description"),
            description=info.get("description"),
            thumbnail=info.get("thumbnail"),
            uploader=info.get("uploader") or info.get("channel"),
            duration=info.get("duration"),
            platform=detect_platform(url) or info.get("extractor_key"),
            extractor=info.get("extractor"),
            formats=formats,
        )
    except yt_dlp.utils.DownloadError as exc:
        return AnalyzeResponse(url=url, error=str(exc))
    except Exception as exc:
        return AnalyzeResponse(url=url, error=f"Analysis failed: {exc}")


def prepare_download(url: str, format_id: str) -> tuple[dict[str, Any], dict[str, Any], str]:
    """Return yt-dlp options, extracted info, and output extension hint."""
    info = _extract_info(url)
    resolved_id = _resolve_format_id(info, format_id)
    fmt = _find_format(info, resolved_id)
    headers = _page_headers(info, url)
    selector = _format_selector(info, format_id)
    ext_hint = str((fmt or {}).get("ext") or info.get("ext") or "mp4")

    opts: dict[str, Any] = {
        **_base_opts(),
        "format": selector,
        "merge_output_format": "mp4",
        "referer": headers["Referer"],
        "http_headers": headers,
        "retries": 10,
        "fragment_retries": 25,
        "file_access_retries": 5,
        "check_formats": False,
        "concurrent_fragment_downloads": 1,
        "hls_use_mpegts": False,
        "noplaylist": True,
    }

    if _needs_merge(fmt):
        opts["merge_output_format"] = "mp4"
        ext_hint = "mp4"

    return opts, info, ext_hint


def direct_stream_target(url: str, format_id: str) -> tuple[str, dict[str, str], str, str | None] | None:
    """If the format is a plain HTTP file, return URL + headers for proxy streaming."""
    if format_id == "best":
        return None

    info = _extract_info(url)
    resolved_id = _resolve_format_id(info, format_id)
    fmt = _find_format(info, resolved_id)
    if fmt is None or _is_fake_video_stub(fmt):
        return None

    direct = fmt.get("url")
    if not direct:
        return None

    protocol = str(fmt.get("protocol") or "").lower()
    if "m3u8" in protocol or "dash" in protocol or "f4m" in protocol:
        return None
    if ".m3u8" in direct or ".mpd" in direct:
        return None

    is_video, is_audio, _ = _classify_format(fmt)
    if is_video and not is_audio:
        return None

    headers = _page_headers(info, url)
    ext = str(fmt.get("ext") or "mp4")
    return direct, headers, ext, info.get("title")
