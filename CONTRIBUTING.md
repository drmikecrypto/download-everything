# Contributing to Download Everything

Thank you for helping make the internet's easiest ad-free media downloader better.

**Maintainer:** [drmikecrypto](https://github.com/drmikecrypto)

## How to contribute

1. **Fork** the repo and create a branch from `main`.
2. **Set up locally** with `docker compose up --build` or run API + web separately (see README).
3. **Make your change** — keep diffs focused.
4. **Test** your change against real URLs when touching extraction logic.
5. **Open a pull request** with a clear description of what and why.

## What we welcome

- New platform-specific SEO landing pages
- yt-dlp version bumps and extractor fixes
- UI/UX improvements
- Performance optimizations
- Accessibility fixes
- Documentation and translations
- Bug reports with reproducible URLs

## What we don't merge

- Changes that add ads, tracking, or paywalls
- Code that weakens the commercial-use restrictions
- Features designed primarily for corporate resale

## Code style

- **Python (API):** PEP 8, type hints, minimal dependencies
- **TypeScript (Web):** Astro conventions, semantic HTML for SEO

## License

By contributing, you agree your work is licensed under AGPL-3.0 plus the [Commercial Restrictions](LICENSE-COMMERCIAL-RESTRICTIONS.md).

## Questions?

Open a [GitHub Discussion](https://github.com/drmikecrypto/download-everything/discussions) or issue.
