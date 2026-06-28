# Download Everything

**[→ Open the live app — paste a link and download](https://download-everything.pages.dev)**

The free, ad-free, open-source way to download videos from anywhere on the internet.

Paste a link. Pick your quality. Download. No signup. No ads. No tracking.

[![Live App](https://img.shields.io/badge/Live_App-Open_Now-00d2a0?style=for-the-badge)](https://download-everything.pages.dev)
[![Desktop & Mobile](https://img.shields.io/badge/Download-Windows_macOS_Linux_Android-6c5ce7?style=for-the-badge)](https://github.com/drmikecrypto/download-everything/releases)
[![API](https://img.shields.io/badge/API-FastAPI-009688)](apps/api)
[![Web](https://img.shields.io/badge/Web-Astro-BC52EE)](apps/web)
[![License](https://img.shields.io/badge/License-AGPL--3.0%2BNC-blue)](LICENSE)

## Native apps (Windows, macOS, Linux, Android)

Install the desktop or mobile app from **[GitHub Releases](https://github.com/drmikecrypto/download-everything/releases)** — no browser required.

| Platform | File |
|----------|------|
| Windows | `download-everything-windows-x64.zip` |
| macOS | `download-everything-macos-universal.zip` |
| Linux | `download-everything-linux-x64.tar.gz` |
| Android | `download-everything-android.apk` |

Built with Flutter (`apps/client`). Uses the same API as the website; optional local [Docker API](apps/api) for full yt-dlp support.

## Supported platforms

| Platform | Stories | Reels / Shorts | Posts | Videos |
|----------|---------|----------------|-------|--------|
| Instagram | ✓ | ✓ | ✓ | ✓ |
| TikTok | — | ✓ | ✓ | ✓ |
| YouTube | — | ✓ (Shorts) | — | ✓ |
| X (Twitter) | — | — | ✓ | ✓ |
| **1,800+ more sites** | via [yt-dlp](https://github.com/yt-dlp/yt-dlp) extractors |

## Quick start

### Run locally (full stack)

```bash
docker compose up --build
```

- **Web UI**: http://localhost:4321
- **API**: http://localhost:8000/docs

### Run API only

```bash
cd apps/api
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

### Run web only

```bash
cd apps/web
npm install
npm run dev
```

Set `PUBLIC_API_URL=http://localhost:8000` in `apps/web/.env`.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  Astro SSG Frontend (Cloudflare Pages or GitHub Pages)      │
│  SEO · JSON-LD · sitemap · zero ads · privacy-first         │
└──────────────────────────┬──────────────────────────────────┘
                           │ HTTPS
┌──────────────────────────▼──────────────────────────────────┐
│  Cloudflare Worker API (always-on edge)                       │
│  YouTube · TikTok · Instagram · X · optional yt-dlp fallback  │
│  /analyze  (metadata + qualities)   /download (stream)      │
└─────────────────────────────────────────────────────────────┘
```

## Deploy

### Cloudflare Workers + Pages (recommended — always on, free tier)

The **edge API** runs on [Cloudflare Workers](https://developers.cloudflare.com/workers/) (no sleep, no cold starts). The **Astro frontend** can live on [Cloudflare Pages](https://developers.cloudflare.com/pages/) or GitHub Pages.

1. Create a [Cloudflare API token](https://dash.cloudflare.com/profile/api-tokens) with **Workers Scripts Edit** and **Cloudflare Pages Edit**.
2. Add GitHub repository secrets:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID` (from the Cloudflare dashboard URL)
3. Push to `main` — `.github/workflows/deploy-cloudflare.yml` deploys:
   - **Worker API** → `https://download-everything-api.<your-subdomain>.workers.dev`
   - **Pages site** → `https://download-everything.pages.dev`
4. Optional: set repo variable `PUBLIC_API_URL` to your Worker URL if the default subdomain differs.

**Worker vs Docker API:** Workers handle YouTube, TikTok, Instagram, and X natively at the edge. For **1,800+ yt-dlp sites**, self-host `apps/api` (Docker) and set Worker secret `YTDLP_BACKEND` to that URL as a fallback.

```bash
cd apps/worker
npm install
npx wrangler deploy
```

Local Worker dev:

```bash
cd apps/worker && npm run dev
# API at http://127.0.0.1:8787
```

### GitHub Pages (optional legacy)

The primary frontend is **[Cloudflare Pages](https://download-everything.pages.dev)** (deployed by `.github/workflows/deploy-cloudflare.yml`). GitHub Pages is not configured for this repo; use Cloudflare Pages instead.

### Docker API (full yt-dlp — optional backend)

For universal site support or local development:

```bash
docker compose up --build
```

You can still deploy `apps/api` to any VPS. **Avoid Render free tier** for production — it sleeps after ~15 min idle (30–60s cold start). Do not ping it on a schedule; that keeps the instance awake and can OOM the 512MB plan.

```bash
docker build -t download-everything-api ./apps/api
docker run -p 8000:8000 -e CORS_ORIGINS=https://download-everything.pages.dev download-everything-api
```

## API

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/health` | GET | Liveness check |
| `/analyze` | POST | `{ "url": "..." }` → title, thumbnail, formats |
| `/download` | GET | `?url=...&format_id=...` → streamed file |

Interactive docs at `/docs` when the API is running.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

Licensed under **AGPL-3.0** with [additional commercial restrictions](LICENSE-COMMERCIAL-RESTRICTIONS.md).  
Individuals and nonprofits may use, modify, and contribute freely. **Corporations may not build commercial products or services based on this project** without written permission from [drmikecrypto](https://github.com/drmikecrypto).

## Author

**[drmikecrypto](https://github.com/drmikecrypto)**
