# Download Everything

The free, ad-free, open-source way to download videos from anywhere on the internet.

**Install the app** — paste a link, pick your quality, download. No hosted web app. No signup. No ads. No tracking.

[![Desktop & Mobile](https://img.shields.io/badge/Download-Windows_macOS_Linux_Android-6c5ce7?style=for-the-badge)](https://github.com/drmikecrypto/download-everything/releases)
[![License](https://img.shields.io/badge/License-AGPL--3.0%2BNC-blue)](LICENSE)

## Download the app

Get the latest build from **[GitHub Releases](https://github.com/drmikecrypto/download-everything/releases)**.

| Platform | File |
|----------|------|
| Windows | `download-everything-windows-x64.zip` |
| macOS | `download-everything-macos-universal.zip` |
| Linux | `download-everything-linux-x64.tar.gz` |
| Android | `download-everything-android.apk` |

Built with Flutter (`apps/client`). Downloads run **locally** via bundled [yt-dlp](https://github.com/yt-dlp/yt-dlp) — Instagram, TikTok, YouTube, X, and 1,800+ sites. No cloud API required.

### Instagram stories & login-walled media

Stories and some private content need a session. In **Settings**, import a Netscape `cookies.txt` exported from your browser (e.g. “Get cookies.txt LOCALLY”). Cookies stay on your device.

## Supported platforms

| Platform | Stories | Reels / Shorts | Posts | Videos |
|----------|---------|----------------|-------|--------|
| Instagram | ✓ (cookies) | ✓ | ✓ | ✓ |
| TikTok | — | ✓ | ✓ | ✓ |
| YouTube | — | ✓ (Shorts) | — | ✓ |
| X (Twitter) | — | — | ✓ | ✓ |
| **1,800+ more sites** | via [yt-dlp](https://github.com/yt-dlp/yt-dlp) extractors |

## Develop the app

```bash
cd apps/client
flutter pub get
dart run tool/fetch_binaries.dart   # desktop: yt-dlp + ffmpeg next to the build
flutter run
```

Tag a release with `app-v*` (or run the **Release Desktop & Mobile Apps** workflow) to publish artifacts.

## Optional Docker API (developers)

For a standalone yt-dlp HTTP API (not required by the app):

```bash
cd apps/api
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

Or `docker compose up --build` for the API + legacy web UI used in local development only. There is **no** public Cloudflare deployment.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Flutter app (Windows · macOS · Linux · Android)            │
│  Analyze → pick quality → download to disk                  │
└──────────────────────────┬──────────────────────────────────┘
                           │ local process / native embed
┌──────────────────────────▼──────────────────────────────────┐
│  yt-dlp + ffmpeg (bundled)                                  │
│  1,800+ extractors · optional cookies.txt                   │
└─────────────────────────────────────────────────────────────┘
```

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under **AGPL-3.0** with [additional commercial restrictions](LICENSE-COMMERCIAL-RESTRICTIONS.md).  
Individuals and nonprofits may use, modify, and contribute freely. **Corporations may not build commercial products or services based on this project** without written permission from [drmikecrypto](https://github.com/drmikecrypto).

## Author

**[drmikecrypto](https://github.com/drmikecrypto)**
