import 'package:flutter/services.dart';

/// Reads WebView CookieManager cookies (includes HttpOnly, e.g. Instagram sessionid).
class WebCookieBridge {
  static const _channel = MethodChannel('com.drmikecrypto.download_everything/cookies');

  static Future<String?> getCookies(String url) async {
    try {
      final value = await _channel.invokeMethod<String>('getCookies', {'url': url});
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<void> clearCookies() async {
    try {
      await _channel.invokeMethod<void>('clearCookies');
    } on MissingPluginException {
      // Desktop / unsupported — ignore.
    } on PlatformException {
      // Best-effort.
    }
  }
}
