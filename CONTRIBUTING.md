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
- Package-manager manifests under `packaging/` (Winget / Scoop / Homebrew)

## Release CI secrets (maintainers)

Android release signing (optional but recommended). Without these, CI falls back to debug signing:

| Secret | Purpose |
|--------|---------|
| `ANDROID_KEYSTORE_BASE64` | Base64-encoded `.jks` / `.keystore` |
| `ANDROID_KEYSTORE_PASSWORD` | Keystore password |
| `ANDROID_KEY_ALIAS` | Key alias |
| `ANDROID_KEY_PASSWORD` | Key password |

Flutter is pinned in `.github/workflows/release-client.yml` (see comments) so macOS AOT builds stay green.

Tag releases as `app-vX.Y.Z` only. `workflow_dispatch` requires the same tag format.

## What we don't merge

- Changes that add ads, tracking, or paywalls
- Restoring a public/cloud download API as the primary product
- Code that weakens the commercial-use restrictions
- Features designed primarily for corporate resale

## Code style

- **Dart/Flutter (`apps/client`):** match existing structure; prefer small focused services
- **Python (`apps/api`):** PEP 8, type hints, minimal dependencies
- **Commits:** author as yourself; do not add Cursor/AI co-author trailers unless you intentionally want them
- Keep `apps/client/lib/app_version.dart` `kAppVersion` in sync with `pubspec.yaml` (`dart run tool/check_version.dart`)

## License

By contributing, you agree your work is licensed under AGPL-3.0 plus the [Commercial Restrictions](LICENSE-COMMERCIAL-RESTRICTIONS.md).

## Questions?

Open an issue or ping [@drmikecrypto](https://github.com/drmikecrypto). Optional support: [GitHub Sponsors](https://github.com/sponsors/drmikecrypto).
