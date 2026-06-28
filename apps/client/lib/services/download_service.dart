import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../utils/formatters.dart';

class DownloadResult {
  const DownloadResult({required this.path, required this.filename});

  final String path;
  final String filename;
}

class DownloadService {
  Future<DownloadResult> download({
    required String url,
    required String title,
    required String ext,
    String? saveDirectory,
    void Function(double progress)? onProgress,
  }) async {
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(url));
      final response = await client.send(request).timeout(const Duration(minutes: 30));

      if (response.statusCode != 200) {
        final body = await response.stream.bytesToString();
        throw Exception('Download failed (${response.statusCode}): $body');
      }

      final filename = _filenameFromHeaders(response.headers, title, ext);
      final dir = saveDirectory ?? await _defaultDownloadDir();
      await Directory(dir).create(recursive: true);
      final filePath = p.join(dir, filename);
      final file = File(filePath);
      final sink = file.openWrite();

      final total = response.contentLength ?? 0;
      var received = 0;

      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress?.call(received / total);
        } else {
          onProgress?.call(-1);
        }
      }

      await sink.close();
      onProgress?.call(1);
      return DownloadResult(path: filePath, filename: filename);
    } finally {
      client.close();
    }
  }

  Future<String> _defaultDownloadDir() async {
    if (Platform.isAndroid) {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir.path;
    }
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'] ??
          '';
      if (home.isNotEmpty) {
        final downloads = p.join(home, 'Downloads', 'DownloadEverything');
        return downloads;
      }
    }
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'DownloadEverything');
  }

  String _filenameFromHeaders(
    Map<String, String> headers,
    String title,
    String ext,
  ) {
    final disposition = headers['content-disposition'] ?? headers['Content-Disposition'];
    if (disposition != null) {
      final utf8Match = RegExp(r"filename\*=UTF-8''([^;\s]+)").firstMatch(disposition);
      if (utf8Match != null) {
        return sanitizeFilename(Uri.decodeComponent(utf8Match.group(1)!));
      }
      final quotedMatch = RegExp(r'filename="([^"]+)"').firstMatch(disposition);
      if (quotedMatch != null) {
        return sanitizeFilename(quotedMatch.group(1)!);
      }
    }
    final safeTitle = sanitizeFilename(title);
    final cleanExt = ext.replaceAll('.', '');
    return '$safeTitle.$cleanExt';
  }
}
