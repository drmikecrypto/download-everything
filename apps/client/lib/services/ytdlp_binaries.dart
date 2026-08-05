import 'dart:io';

import 'package:path/path.dart' as p;

/// Resolves bundled yt-dlp / ffmpeg next to the app or in `binaries/`.
class YtdlpBinaries {
  YtdlpBinaries._();

  static String get ytdlpName {
    if (Platform.isWindows) return 'yt-dlp.exe';
    return 'yt-dlp';
  }

  static String get ffmpegName {
    if (Platform.isWindows) return 'ffmpeg.exe';
    return 'ffmpeg';
  }

  static Future<String> resolveYtdlp() async {
    final path = await _find(ytdlpName);
    if (path == null) {
      throw StateError(
        'yt-dlp not found. Run: dart run tool/fetch_binaries.dart',
      );
    }
    return path;
  }

  static Future<String?> resolveFfmpeg() async => _find(ffmpegName);

  static Future<String?> _find(String name) async {
    final candidates = <String>[
      p.join(File(Platform.resolvedExecutable).parent.path, name),
      p.join(Directory.current.path, 'binaries', _platformDir(), name),
      p.join(Directory.current.path, 'apps', 'client', 'binaries', _platformDir(), name),
    ];

    // When running from apps/client
    final scriptBin = p.join(Directory.current.path, 'binaries', _platformDir(), name);
    if (!candidates.contains(scriptBin)) candidates.add(scriptBin);

    for (final candidate in candidates) {
      final file = File(candidate);
      if (await file.exists()) return file.absolute.path;
    }
    return null;
  }

  static String _platformDir() {
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    if (Platform.isLinux) return 'linux';
    return 'unknown';
  }
}
