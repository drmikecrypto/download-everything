# Download Everything — Native Client

Cross-platform desktop and mobile app for [Download Everything](https://github.com/drmikecrypto/download-everything).

## Platforms

| Platform | Download |
|----------|----------|
| Windows  | `download-everything-windows-x64.zip` from [Releases](https://github.com/drmikecrypto/download-everything/releases) |
| macOS    | `download-everything-macos-universal.zip` |
| Linux    | `download-everything-linux-x64.tar.gz` |
| Android  | `download-everything-android.apk` |

## Features

- Paste or share a video link — analyze formats instantly
- Pick quality and save to your Downloads folder
- Uses the public Cloudflare Worker API by default (always on)
- Optional custom API URL for local [Docker yt-dlp backend](../api) (1,800+ sites)

## Develop locally

```bash
cd apps/client
flutter pub get
dart run tool/generate_icon.dart
dart run flutter_launcher_icons
flutter run -d windows   # or macos, linux, android
```

## Build release binaries

```bash
flutter build windows --release
flutter build macos --release
flutter build linux --release
flutter build apk --release
```

CI builds all four platforms when you push a tag like `app-v1.0.0` (see `.github/workflows/release-client.yml`).

## License

AGPL-3.0 — same as the main project.
