# AGENTS.md — DEF (Download Everything Forever)

Guidance for AI coding assistants and autonomous agents working in this repository.

## Project identity

- **Name:** DEF (short for Download Everything Forever)
- **Owner:** drmikecrypto (only author/maintainer credit — do not add co-authors or Cursor attribution in commits)
- **What it is:** Free ad-free universal media downloader (Instagram, TikTok, YouTube, X, 1800+ sites via yt-dlp)
- **How users get it:** GitHub Releases only — no public live web/API hosting

## Source of truth

| Area | Path |
|------|------|
| Primary product (Flutter) | `apps/client` |
| Brand constants | `apps/client/lib/app_brand.dart` |
| Local yt-dlp engine (Dart) | `apps/client/lib/services/ytdlp_*.dart` |
| Browser companion bridge | `apps/client/lib/services/browser_bridge_service.dart` + `extensions/` |
| Android native bridge | `apps/client/android/.../MainActivity.kt` |
| Desktop binary fetch | `apps/client/tool/fetch_binaries.dart` |
| Optional yt-dlp HTTP API | `apps/api` |
| Release CI | `.github/workflows/release-client.yml` |
| Client CI | `.github/workflows/client-ci.yml` |
| Packaging | `packaging/` |
| LLM/crawler summary | `llms.txt` |
| Human overview | `README.md` |

## Architecture rules

1. Prefer **local yt-dlp** in the Flutter app — do not restore a public Cloudflare Worker/Pages download service.
2. Keep UX: analyze URL → list formats → download to disk.
3. Instagram Stories / login walls: optional `cookies.txt` via Settings (`SettingsService.cookiesPath`).
4. `apps/web` and `apps/worker` are legacy/retired for hosting; do not advertise them as the product.
5. Release tags must match `app-v*` to trigger desktop/mobile builds.
6. User-facing name is **DEF**; keep Dart package / Android `applicationId` as `download_everything` for upgrade stability.

## Common tasks

- **Run desktop app:** `cd apps/client && dart run tool/fetch_binaries.dart && flutter run`
- **Bump app version:** `apps/client/pubspec.yaml`
- **Ship release:** push tag `app-vX.Y.Z`

## Do not

- Add ads, tracking, or mandatory cloud backends
- Commit secrets or user cookies
- Add `Co-authored-by: Cursor` or other agent co-contributor trailers
- Weaken LICENSE commercial restrictions
