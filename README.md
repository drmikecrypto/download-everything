# Download Everything — Free Video Downloader (Instagram, TikTok, YouTube, X)

**Download Everything** is a free, ad-free, open-source **video downloader** for **Windows, macOS, Linux, and Android**. Paste a link, pick quality, save to disk. Powered by [yt-dlp](https://github.com/yt-dlp/yt-dlp) with **1,800+ site extractors**. No signup. No ads. No tracking. Runs entirely on your device.

[![Download apps](https://img.shields.io/badge/Download-Windows%20%7C%20macOS%20%7C%20Linux%20%7C%20Android-6c5ce7?style=for-the-badge)](https://github.com/drmikecrypto/download-everything/releases/latest)
[![Release](https://img.shields.io/github/v/release/drmikecrypto/download-everything?style=for-the-badge)](https://github.com/drmikecrypto/download-everything/releases/latest)
[![License](https://img.shields.io/badge/License-AGPL--3.0%2BNC-blue?style=for-the-badge)](LICENSE)
[![Stars](https://img.shields.io/github/stars/drmikecrypto/download-everything?style=for-the-badge)](https://github.com/drmikecrypto/download-everything/stargazers)

> **Looking for:** free Instagram Reels downloader · Instagram Stories downloader · TikTok video saver · YouTube Shorts downloader · X/Twitter video download · yt-dlp GUI for desktop and Android

## Quick start

1. Open **[Releases](https://github.com/drmikecrypto/download-everything/releases/latest)**
2. Download your platform build
3. Paste a video URL → choose quality → download

| Platform | File |
|----------|------|
| Windows | `download-everything-windows-x64.zip` |
| macOS | `download-everything-macos-universal.zip` |
| Linux | `download-everything-linux-x64.tar.gz` |
| Android | `download-everything-android.apk` |

### Package managers (templates)

Manifests live under [`packaging/`](packaging/) (Winget, Scoop, Homebrew Cask). Update hashes after each release, then publish to the respective repos/taps.

Windows/macOS SmartScreen or Gatekeeper may warn until desktop code-signing/notarization is added — prefer the GitHub Releases page as the trusted source.

There is **no online web app**. Anyone who wants to use it installs the app from Releases.

[![Sponsor](https://img.shields.io/badge/Sponsor-GitHub-ea4aaa?style=for-the-badge&logo=githubsponsors)](https://github.com/sponsors/drmikecrypto)

## Why this app

| Feature | Detail |
|---------|--------|
| Universal | Instagram, TikTok, YouTube, X (Twitter), Vimeo, Reddit, SoundCloud, and 1,800+ sites via yt-dlp |
| Private by design | Extraction happens locally — no cloud download API, no accounts |
| Ad-free | No upsells, redirects, or malware landers |
| Offline capable | Once installed, you only need network access to the media host |
| Stories support | Instagram Stories work when you import a browser `cookies.txt` |
| Queue & playlists | Queue multiple downloads; analyze playlists and download all items |
| Updates | Hidden until a newer `app-v*` GitHub Release exists — then an Update control appears |

## Supported sites (examples)

| Site | Stories | Reels / Shorts | Posts | Videos |
|------|---------|----------------|-------|--------|
| Instagram | ✓ (cookies) | ✓ | ✓ | ✓ |
| TikTok | — | ✓ | ✓ | ✓ |
| YouTube | — | ✓ (Shorts) | — | ✓ |
| X (Twitter) | — | — | ✓ | ✓ |
| **1,800+ more** | via [yt-dlp extractors](https://github.com/yt-dlp/yt-dlp/blob/master/supportedsites.md) | | | |

### Instagram Stories & login-walled media

In **Settings**, import a Netscape `cookies.txt` (e.g. browser extension “Get cookies.txt LOCALLY”). Cookies stay on your device and enable Stories / some private media.

## How it works

```
Flutter app (Windows · macOS · Linux · Android)
        │
        ▼
Bundled yt-dlp + ffmpeg  →  file saved to Downloads
```

- **Desktop:** ships `yt-dlp` and `ffmpeg` next to the app
- **Android:** embeds yt-dlp via youtubedl-android
- Optional developer API: `apps/api` (FastAPI + yt-dlp) for local automation

## FAQ

### Is Download Everything free?
Yes. Free, open source, and ad-free for individuals and nonprofits (see license).

### Does it download Instagram Reels, Stories, and TikTok?
Yes for public Reels/TikTok/YouTube/X in most cases. Instagram Stories usually need a `cookies.txt` from your logged-in browser session.

### Is this a yt-dlp GUI?
Yes — a native Flutter front-end around yt-dlp for people who want paste-link → pick-quality → save, without the terminal.

### Do I need Docker or a server?
No for normal use. Install the app from Releases. Docker/`apps/api` is optional for developers.

### Where do files save?
By default under your Downloads folder (`DownloadEverything`). Desktop can ask for a folder each time in Settings.

### Who maintains this?
[**drmikecrypto**](https://github.com/drmikecrypto)

## Develop

```bash
cd apps/client
flutter pub get
dart run tool/fetch_binaries.dart   # desktop binaries
flutter run
```

See [`apps/client/README.md`](apps/client/README.md), [`llms.txt`](llms.txt) (machine-readable summary), and [`AGENTS.md`](AGENTS.md) (AI/agent map of the repo).

Tag `app-v*` to publish builds via GitHub Actions.

## Related project files

| Path | Purpose |
|------|---------|
| [`apps/client`](apps/client) | Flutter desktop & Android app (primary product) |
| [`apps/api`](apps/api) | Optional local FastAPI + yt-dlp HTTP API |
| [`apps/web`](apps/web) | Legacy static UI for local docker-compose only |
| [`apps/worker`](apps/worker) | Retired Cloudflare Worker (not deployed) |
| [`llms.txt`](llms.txt) | Concise facts for LLMs and crawlers |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

**AGPL-3.0** with [additional commercial restrictions](LICENSE-COMMERCIAL-RESTRICTIONS.md).  
Individuals and nonprofits may use, modify, and contribute freely. **Corporations may not build commercial products or services based on this project** without written permission from [drmikecrypto](https://github.com/drmikecrypto).

## Author

**[drmikecrypto](https://github.com/drmikecrypto)** — free open-source tools.
