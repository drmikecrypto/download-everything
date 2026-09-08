import 'dart:io';

import '../models/media.dart';
import 'download_service.dart';
import 'ytdlp_android.dart';
import 'ytdlp_desktop.dart';
import 'ytdlp_exception.dart';

export 'ytdlp_exception.dart';

/// Cross-platform facade over bundled yt-dlp.
class YtdlpEngine {
  YtdlpEngine();

  final _desktop = YtdlpDesktop();
  final _android = YtdlpAndroid();

  /// Last analyze info map (used for smarter format selectors on download).
  Map<String, dynamic>? lastInfo;

  Future<void> ensureReady() async {
    if (Platform.isAndroid) {
      await _android.ensureReady();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      await _desktop.ensureReady();
    } else {
      throw YtdlpException('Unsupported platform');
    }
  }

  Future<AnalyzeResponse> analyze(
    String url, {
    String? cookiesPath,
    bool allowPlaylist = false,
  }) async {
    final AnalyzeResponse response;
    if (Platform.isAndroid) {
      response = await _android.analyze(
        url,
        cookiesPath: cookiesPath,
        allowPlaylist: allowPlaylist,
      );
    } else {
      response = await _desktop.analyze(
        url,
        cookiesPath: cookiesPath,
        allowPlaylist: allowPlaylist,
      );
    }
    lastInfo = response.rawInfo;
    return response;
  }

  Future<DownloadResult> download({
    required String url,
    required String formatId,
    required String title,
    required String ext,
    String? saveDirectory,
    String? cookiesPath,
    bool writeSubs = false,
    bool sponsorBlock = false,
    void Function(double progress)? onProgress,
  }) async {
    if (Platform.isAndroid) {
      return _android.download(
        url: url,
        formatId: formatId,
        title: title,
        ext: ext,
        saveDirectory: saveDirectory,
        cookiesPath: cookiesPath,
        info: lastInfo,
        writeSubs: writeSubs,
        sponsorBlock: sponsorBlock,
        onProgress: onProgress,
      );
    }
    return _desktop.download(
      url: url,
      formatId: formatId,
      title: title,
      ext: ext,
      saveDirectory: saveDirectory,
      cookiesPath: cookiesPath,
      info: lastInfo,
      writeSubs: writeSubs,
      sponsorBlock: sponsorBlock,
      onProgress: onProgress,
    );
  }

  Future<String> version() async {
    if (Platform.isAndroid) return _android.version();
    return _desktop.version();
  }

  Future<void> updateYtdlp() async {
    if (Platform.isAndroid) {
      await _android.updateYtdlp();
      return;
    }
    await _desktop.updateYtdlp();
  }
}
