# Contributing to Download Everything

Thank you for helping improve a free, ad-free media downloader.

**Maintainer:** [drmikecrypto](https://github.com/drmikecrypto)

## How to contribute

1. **Fork** the repo and create a branch from `main`.
2. **Set up the Flutter app** (`apps/client`) — see [README.md](README.md) and [apps/client/README.md](apps/client/README.md).
3. **Make your change** — keep diffs focused.
4. **Test** against real URLs when touching extraction or download logic.
5. **Open a pull request** with a clear description of what and why.

## What we welcome

- yt-dlp / ffmpeg packaging and update improvements
- Extractor UX, error messages, and cookies-flow polish
- Desktop and Android stability fixes
- Accessibility and localization
- Documentation that helps people find and use the app
- Bug reports with reproducible URLs (redact private cookies)

## What we don't merge

- Changes that add ads, tracking, or paywalls
- Restoring a public/cloud download API as the primary product
- Code that weakens the commercial-use restrictions
- Features designed primarily for corporate resale

## Code style

- **Dart/Flutter (`apps/client`):** match existing structure; prefer small focused services
- **Python (`apps/api`):** PEP 8, type hints, minimal dependencies
- **Commits:** author as yourself; do not add Cursor/AI co-author trailers unless you intentionally want them

## License

By contributing, you agree your work is licensed under AGPL-3.0 plus the [Commercial Restrictions](LICENSE-COMMERCIAL-RESTRICTIONS.md).

## Questions?

Open an issue or ping [@drmikecrypto](https://github.com/drmikecrypto).
