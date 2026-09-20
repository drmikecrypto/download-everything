import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../app_brand.dart';

/// Localhost HTTP bridge so a browser extension can send the current tab URL to DEF.
///
/// Listens on loopback only. Bind failures are non-fatal (desktop-only feature).
class BrowserBridgeService {
  BrowserBridgeService({this.onUrl});

  /// Invoked when a URL is received from the companion extension.
  void Function(String url, {String? cookies})? onUrl;

  HttpServer? _server;
  bool get isRunning => _server != null;

  Future<void> start() async {
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
    if (_server != null) return;
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        kBrowserBridgePort,
      );
      _server!.listen(_handle, onError: (Object e) {
        if (kDebugMode) debugPrint('DEF bridge listen error: $e');
      });
      if (kDebugMode) {
        debugPrint('DEF browser bridge on 127.0.0.1:$kBrowserBridgePort');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('DEF browser bridge failed to bind: $e');
      _server = null;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    void cors() {
      request.response.headers
        ..set('Access-Control-Allow-Origin', '*')
        ..set('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        ..set('Access-Control-Allow-Headers', 'Content-Type');
    }

    cors();

    if (request.method == 'OPTIONS') {
      request.response.statusCode = HttpStatus.noContent;
      await request.response.close();
      return;
    }

    if (request.uri.path == '/health' && request.method == 'GET') {
      request.response
        ..statusCode = HttpStatus.ok
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'ok': true, 'app': kAppName}));
      await request.response.close();
      return;
    }

    if (request.uri.path == '/v1/open' && request.method == 'POST') {
      try {
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body);
        if (decoded is! Map) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        final url = decoded['url']?.toString().trim() ?? '';
        final cookies = decoded['cookies']?.toString();
        if (url.isEmpty || !url.startsWith('http')) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          return;
        }
        onUrl?.call(url, cookies: cookies);
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'ok': true}));
      } catch (e) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.write('$e');
      }
      await request.response.close();
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }
}
