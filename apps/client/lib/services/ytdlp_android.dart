import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/media.dart';
import '../utils/formatters.dart';
import 'download_service.dart';
import 'ytdlp_exception.dart';
import 'ytdlp_format_parser.dart';

/// Android MethodChannel bridge to youtubedl-android.
class YtdlpAndroid {
  static const _channel = MethodChannel('com.drmikecrypto.download_everything/ytdlp');
  static const _events = EventChannel('com.drmikecrypto.download_everything/ytdlp_progress');

  bool _ready = false;

  Future<void> ensureReady() async {
    if (_ready) return;
    try {
      await _channel.invokeMethod<void>('initialize');
      _ready = true;
    } on PlatformException catch (e) {
      throw YtdlpException(
        e.message ??
            'Failed to start yt-dlp on Android (${e.code}). Reinstall the app or free storage and try again.',
      );
    } on MissingPluginException {
      throw YtdlpException('yt-dlp native plugin is missing from this Android build.');
    }
  }

  Future<AnalyzeResponse> analyze(String url, {String? cookiesPath}) async {
    await ensureReady();
    try {
      final raw = await _channel.invokeMethod<String>('analyze', {
        'url': url,
        'cookiesPath': cookiesPath,
      });
      if (raw == null || raw.isEmpty) {
        return AnalyzeResponse(url: url, formats: const [], error: 'Empty response from yt-dlp');
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return AnalyzeResponse(url: url, formats: const [], error: 'Unexpected yt-dlp JSON');
      }
      var info = Map<String, dynamic>.from(decoded);
      if (info['_type'] == 'playlist' && info['entries'] is List && (info['entries'] as List).isNotEmpty) {
        final entry = (info['entries'] as List).first;
        if (entry is Map) {
          info = Map<String, dynamic>.from(entry);
        }
      }
      return analyzeResponseFromInfo(url, info);
    } on PlatformException catch (e) {
      return AnalyzeResponse(
        url: url,
        formats: const [],
        error: _friendlyError(url, e.message ?? e.code),
      );
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
    void Function(double progress)? onProgress,
  }) async {
    await ensureReady();
    final dir = saveDirectory ?? await _defaultDownloadDir();
    await Directory(dir).create(recursive: true);

    final safeTitle = sanitizeFilename(title);
    final outTemplate = p.join(dir, '$safeTitle.%(ext)s');
    final selector = formatSelector(formatId, info);

    StreamSubscription? sub;
    if (onProgress != null) {
      sub = _events.receiveBroadcastStream().listen((event) {
        if (event is Map && event['progress'] is num) {
          onProgress((event['progress'] as num).toDouble().clamp(0, 100) / 100.0);
        }
      });
    }

    try {
      final path = await _channel.invokeMethod<String>('download', {
        'url': url,
        'format': selector,
        'outTemplate': outTemplate,
        'cookiesPath': cookiesPath,
      });
      if (path == null || path.isEmpty) {
        throw YtdlpException('Download finished but no file path was returned.');
      }
      onProgress?.call(1);
      return DownloadResult(path: path, filename: p.basename(path));
    } on PlatformException catch (e) {
      throw YtdlpException(e.message ?? e.code);
    } finally {
      await sub?.cancel();
    }
  }

  Future<String> version() async {
    await ensureReady();
    final v = await _channel.invokeMethod<String>('version');
    return v ?? 'unknown';
  }

  Future<void> updateYtdlp() async {
    await ensureReady();
    await _channel.invokeMethod<void>('update');
  }

  String _friendlyError(String url, String raw) {
    final lower = raw.toLowerCase();
    final isStory = url.toLowerCase().contains('/stories/');
    if (isStory || lower.contains('login') || lower.contains('cookie') || lower.contains('private')) {
      return '$raw\n\nTip: Instagram stories often need cookies. Import a cookies.txt in Settings.';
    }
    return raw;
  }

  Future<String> _defaultDownloadDir() async {
    final dir = await getDownloadsDirectory();
    if (dir != null) return p.join(dir.path, 'DownloadEverything');
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'DownloadEverything');
  }
}
