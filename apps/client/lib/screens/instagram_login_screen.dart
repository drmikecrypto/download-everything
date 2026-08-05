import 'dart:io';

import 'package:flutter/material.dart';

import '../services/instagram_session.dart';
import '../services/settings_service.dart';
import '../services/web_cookie_bridge.dart';

/// Opens Instagram login; returns true if a session was saved.
///
/// In-app login uses a native Android WebView. Desktop uses Advanced cookies.txt.
Future<bool> promptInstagramLogin(BuildContext context, SettingsService settings) async {
  if (!Platform.isAndroid) {
    if (!context.mounted) return false;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instagram on desktop'),
        content: const Text(
          'In-app Instagram sign-in is available on Android. '
          'On desktop, import a Netscape cookies.txt under Settings → Advanced, '
          'or try analyzing without cookies if your yt-dlp build supports it.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
    return false;
  }

  final header = await WebCookieBridge.loginInstagram();
  if (header == null || !header.contains('sessionid=')) return false;

  final session = InstagramSession(settings);
  await session.saveFromCookieHeader(header);
  return true;
}
