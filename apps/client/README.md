# Download Everything — Native Client

Cross-platform desktop and mobile app. Downloads run **locally** with bundled yt-dlp — no cloud API.

## Platforms

| Platform | Download |
|----------|----------|
| Windows  | `download-everything-windows-x64.zip` from [Releases](https://github.com/drmikecrypto/download-everything/releases) |
| macOS    | `download-everything-macos-universal.zip` |
| Linux    | `download-everything-linux-x64.tar.gz` |
| Android  | `download-everything-android.apk` |

## Features

- Paste or share a video link — analyze formats with yt-dlp
- Pick quality and save to your Downloads folder
- Instagram stories / login-walled media via optional `cookies.txt` in Settings
- Desktop ships yt-dlp + ffmpeg; Android embeds youtubedl-android

## Develop locally

```bash
cd apps/client
flutter pub get
dart run tool/generate_icon.dart
dart run flutter_launcher_icons
dart run tool/fetch_binaries.dart   # desktop only — yt-dlp + ffmpeg
flutter run -d windows              # or macos, linux, android
```

## Build release binaries

```bash
dart run tool/fetch_binaries.dart
flutter build windows --release
flutter build macos --release
flutter build linux --release
flutter build apk --release
```

CI builds all four platforms when you push a tag like `app-v1.0.0` (see `.github/workflows/release-client.yml`).

## License

AGPL-3.0 — same as the main project.
