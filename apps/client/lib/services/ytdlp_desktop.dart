import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media.dart';
import '../utils/formatters.dart';
import 'download_service.dart';
import 'ytdlp_binaries.dart';
import 'ytdlp_exception.dart';
import 'ytdlp_format_parser.dart';
import 'ytdlp_options.dart';

/// Desktop implementation: invoke bundled yt-dlp + ffmpeg via Process.
class YtdlpDesktop {
  Future<void> ensureReady() async {
    await YtdlpBinaries.resolveYtdlp();
  }

  Future<AnalyzeResponse> analyze(
    String url, {
    String? cookiesPath,
    bool allowPlaylist = false,
  }) async {
    final ytdlp = await YtdlpBinaries.resolveYtdlp();
    final args = <String>[
      '--dump-single-json',
      '--socket-timeout',
      '30',
      ...commonYtdlpArgs(url, allowPlaylist: allowPlaylist),
      ..._cookieArgs(cookiesPath),
      url,
    ];

    final result = await Process.run(
      ytdlp,
      args,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );

    if (result.exitCode != 0) {
      final err = (result.stderr as String).trim();
      final msg = err.isNotEmpty ? err : 'yt-dlp failed (exit ${result.exitCode})';
      return AnalyzeResponse(url: url, formats: const [], error: _friendlyError(url, msg));
    }

    try {
      final info = jsonDecode(result.stdout as String) as Map<String, dynamic>;
      return analyzeResponseFromInfo(url, info);
    } catch (e) {
      return AnalyzeResponse(url: url, formats: const [], error: 'Failed to parse yt-dlp output: $e');
    }
  }

  Future<DownloadResult> download({
    required String url,
    required String formatId,
    required String title,
    required String ext,
    String? saveDirectory,
    String? cookiesPath,
    Map<String, dynamic>? info,
    bool writeSubs = false,
    bool sponsorBlock = false,
    void Function(double progress)? onProgress,
  }) async {
    final ytdlp = await YtdlpBinaries.resolveYtdlp();
    final ffmpeg = await YtdlpBinaries.resolveFfmpeg();
    final dir = saveDirectory ?? await _defaultDownloadDir();
    await Directory(dir).create(recursive: true);

    final safeTitle = sanitizeFilename(title);
    final outTemplate = p.join(dir, '$safeTitle.%(ext)s');
    final selector = formatSelector(formatId, info);

    final args = <String>[
      '-f',
      selector,
      '--newline',
      '--merge-output-format',
      'mp4',
      '-o',
      outTemplate,
      ...commonYtdlpArgs(
        url,
        allowPlaylist: false,
        writeSubs: writeSubs,
        sponsorBlock: sponsorBlock,
      ),
      ..._cookieArgs(cookiesPath),
      if (ffmpeg != null) ...['--ffmpeg-location', p.dirname(ffmpeg)],
      url,
    ];

    final process = await Process.start(ytdlp, args);
    final stderrBuf = StringBuffer();

    process.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      final progress = parseDownloadProgress(line);
      if (progress != null) onProgress?.call(progress);
    });

    process.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      stderrBuf.writeln(line);
      final progress = parseDownloadProgress(line);
      if (progress != null) onProgress?.call(progress);
    });

    final code = await process.exitCode;
    if (code != 0) {
      final err = stderrBuf.toString().trim();
      throw YtdlpException(err.isNotEmpty ? err : 'Download failed (exit $code)');
    }

    final file = await _findOutputFile(dir, safeTitle, ext);
    if (file == null) {
      throw YtdlpException('Download finished but output file was not found.');
    }

    onProgress?.call(1);
    return DownloadResult(path: file.path, filename: p.basename(file.path));
  }

  Future<String> version({String? cookiesPath}) async {
    final ytdlp = await YtdlpBinaries.resolveYtdlp();
    final result = await Process.run(ytdlp, ['--version']);
    if (result.exitCode != 0) {
      throw YtdlpException('Could not read yt-dlp version');
    }
    return (result.stdout as String).trim();
  }

  /// Downloads the latest yt-dlp binary over the resolved executable path.
  Future<void> updateYtdlp() async {
    final current = await YtdlpBinaries.resolveYtdlp();
    final url = Platform.isWindows
        ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe'
        : Platform.isMacOS
            ? 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos'
            : 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp';

    final response = await http.get(Uri.parse(url)).timeout(const Duration(minutes: 3));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw YtdlpException('Failed to download yt-dlp (HTTP ${response.statusCode})');
    }

    final dest = File(current);
    final tmp = File('${dest.path}.new');
    await tmp.writeAsBytes(response.bodyBytes, flush: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['+x', tmp.path]);
    }
    try {
      if (await dest.exists()) {
        await dest.delete();
      }
    } catch (_) {
      // On Windows the running binary may be locked; try rename swap.
    }
    try {
      await tmp.rename(dest.path);
    } catch (_) {
      await tmp.copy(dest.path);
      await tmp.delete();
    }
  }

  List<String> _cookieArgs(String? cookiesPath) {
    if (cookiesPath == null || cookiesPath.isEmpty) return const [];
    if (!File(cookiesPath).existsSync()) return const [];
    return ['--cookies', cookiesPath];
  }

  String _friendlyError(String url, String raw) {
    return appendInstagramCookiesTip(url, raw);
  }

  Future<String> _defaultDownloadDir() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['USERPROFILE'] ?? Platform.environment['HOME'] ?? '';
      if (home.isNotEmpty) {
        return p.join(home, 'Downloads', 'DownloadEverything');
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'DownloadEverything');
  }

  Future<File?> _findOutputFile(String dir, String safeTitle, String ext) async {
    final preferredExts = <String>{
      ext.replaceAll('.', ''),
      'mp4',
      'mkv',
      'webm',
      'm4a',
      'mp3',
      'opus',
    };

    final directory = Directory(dir);
    if (!await directory.exists()) return null;

    File? best;
    DateTime? bestTime;
    await for (final entity in directory.list()) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!name.startsWith(safeTitle)) continue;
      final fileExt = p.extension(name).replaceFirst('.', '').toLowerCase();
      if (!preferredExts.contains(fileExt) && preferredExts.isNotEmpty) {
        // Still accept if prefix matches and recently written.
      }
      final stat = await entity.stat();
      if (bestTime == null || stat.modified.isAfter(bestTime)) {
        best = entity;
        bestTime = stat.modified;
      }
    }

    if (best == null) {
      final cutoff = DateTime.now().subtract(const Duration(minutes: 2));
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        if (stat.modified.isBefore(cutoff)) continue;
        if (bestTime == null || stat.modified.isAfter(bestTime)) {
          best = entity;
          bestTime = stat.modified;
        }
      }
    }

    return best;
  }
}
