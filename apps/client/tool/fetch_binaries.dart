// Downloads platform yt-dlp + ffmpeg into apps/client/binaries/<platform>/.
// Usage (from apps/client): dart run tool/fetch_binaries.dart
// Optional: dart run tool/fetch_binaries.dart --platform=windows

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

Future<void> main(List<String> args) async {
  final platform = _arg(args, 'platform') ?? _hostPlatform();
  final outDir = Directory(p.join('binaries', platform));
  await outDir.create(recursive: true);

  stdout.writeln('Fetching binaries for $platform → ${outDir.path}');

  switch (platform) {
    case 'windows':
      await _download(
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe',
        File(p.join(outDir.path, 'yt-dlp.exe')),
      );
      await _fetchWindowsFfmpeg(outDir);
      break;
    case 'linux':
      await _download(
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp',
        File(p.join(outDir.path, 'yt-dlp')),
      );
      await _chmod(File(p.join(outDir.path, 'yt-dlp')));
      await _fetchLinuxFfmpeg(outDir);
      break;
    case 'macos':
      await _download(
        'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos',
        File(p.join(outDir.path, 'yt-dlp')),
      );
      await _chmod(File(p.join(outDir.path, 'yt-dlp')));
      await _fetchMacFfmpeg(outDir);
      break;
    default:
      stderr.writeln('Unsupported platform: $platform');
      exit(1);
  }

  stdout.writeln('Done.');
}

String? _arg(List<String> args, String name) {
  final prefix = '--$name=';
  for (final a in args) {
    if (a.startsWith(prefix)) return a.substring(prefix.length);
  }
  return null;
}

String _hostPlatform() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isLinux) return 'linux';
  throw UnsupportedError('Unknown host platform');
}

Future<void> _download(String url, File dest) async {
  stdout.writeln('GET $url');
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException('HTTP ${response.statusCode} for $url');
    }
    final sink = dest.openWrite();
    await response.pipe(sink);
    stdout.writeln('  → ${dest.path} (${await dest.length()} bytes)');
  } finally {
    client.close(force: true);
  }
}

Future<void> _chmod(File file) async {
  if (Platform.isWindows) return;
  await Process.run('chmod', ['+x', file.path]);
}

Future<void> _fetchWindowsFfmpeg(Directory outDir) async {
  final zipPath = p.join(outDir.path, 'ffmpeg.zip');
  await _download(
    'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-win64-gpl.zip',
    File(zipPath),
  );
  final extractDir = Directory(p.join(outDir.path, '_ffmpeg_extract'));
  if (await extractDir.exists()) await extractDir.delete(recursive: true);
  await extractDir.create(recursive: true);

  final unzip = await Process.run('powershell', [
    '-NoProfile',
    '-Command',
    "Expand-Archive -Path '${zipPath.replaceAll("'", "''")}' -DestinationPath '${extractDir.path.replaceAll("'", "''")}' -Force",
  ]);
  if (unzip.exitCode != 0) {
    throw ProcessException('powershell', [], unzip.stderr.toString(), unzip.exitCode);
  }

  final ffmpeg = await _findFile(extractDir, 'ffmpeg.exe');
  if (ffmpeg == null) throw StateError('ffmpeg.exe not found in archive');
  await ffmpeg.copy(p.join(outDir.path, 'ffmpeg.exe'));
  await File(zipPath).delete();
  await extractDir.delete(recursive: true);
}

Future<void> _fetchLinuxFfmpeg(Directory outDir) async {
  final archive = File(p.join(outDir.path, 'ffmpeg.tar.xz'));
  await _download(
    'https://github.com/yt-dlp/FFmpeg-Builds/releases/download/latest/ffmpeg-master-latest-linux64-gpl.tar.xz',
    archive,
  );
  final extractDir = Directory(p.join(outDir.path, '_ffmpeg_extract'));
  if (await extractDir.exists()) await extractDir.delete(recursive: true);
  await extractDir.create(recursive: true);

  final tar = await Process.run('tar', ['-xJf', archive.path, '-C', extractDir.path]);
  if (tar.exitCode != 0) {
    throw ProcessException('tar', [], tar.stderr.toString(), tar.exitCode);
  }

  final ffmpeg = await _findFile(extractDir, 'ffmpeg');
  if (ffmpeg == null) throw StateError('ffmpeg not found in archive');
  final dest = File(p.join(outDir.path, 'ffmpeg'));
  await ffmpeg.copy(dest.path);
  await _chmod(dest);
  await archive.delete();
  await extractDir.delete(recursive: true);
}

Future<void> _fetchMacFfmpeg(Directory outDir) async {
  // Prefer system ffmpeg if present; otherwise download static evermeet-style via homebrew hint.
  final which = await Process.run('which', ['ffmpeg']);
  if (which.exitCode == 0) {
    final path = (which.stdout as String).trim();
    if (path.isNotEmpty) {
      await File(path).copy(p.join(outDir.path, 'ffmpeg'));
      await _chmod(File(p.join(outDir.path, 'ffmpeg')));
      stdout.writeln('Copied system ffmpeg from $path');
      return;
    }
  }

  // Fallback: download universal static build if available via yt-dlp ffmpeg builds (macOS may vary).
  stderr.writeln(
    jsonEncode({
      'warning':
          'No system ffmpeg found. Install ffmpeg (brew install ffmpeg) or place ffmpeg in binaries/macos/.',
    }),
  );
}

Future<File?> _findFile(Directory root, String name) async {
  await for (final entity in root.list(recursive: true, followLinks: false)) {
    if (entity is File && p.basename(entity.path) == name) {
      return entity;
    }
  }
  return null;
}
