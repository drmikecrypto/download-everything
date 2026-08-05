import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

import '../services/instagram_session.dart';
import '../services/settings_service.dart';
import '../services/web_cookie_bridge.dart';
import '../services/ytdlp_options.dart';
import '../theme/app_theme.dart';

/// In-app Instagram login. Saves Netscape cookies and pops `true` on success.
class InstagramLoginScreen extends StatefulWidget {
  const InstagramLoginScreen({super.key, required this.settings});

  final SettingsService settings;

  @override
  State<InstagramLoginScreen> createState() => _InstagramLoginScreenState();
}

class _InstagramLoginScreenState extends State<InstagramLoginScreen> {
  late final WebViewController _controller;
  late final InstagramSession _session;
  Timer? _poll;
  bool _saving = false;
  bool _done = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _session = InstagramSession(widget.settings);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(kMobileUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _checkCookies(),
        ),
      )
      ..loadRequest(Uri.parse(InstagramSession.loginUrl));

    _configureAndroid();
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _checkCookies());
  }

  Future<void> _configureAndroid() async {
    final platform = _controller.platform;
    if (platform is AndroidWebViewController) {
      await AndroidWebViewCookieManager(const PlatformWebViewCookieManagerCreationParams())
          .setAcceptThirdPartyCookies(platform, true);
    }
  }

  Future<void> _checkCookies() async {
    if (_done || _saving || !mounted) return;
    final header = await WebCookieBridge.getCookies(InstagramSession.homeUrl) ??
        await WebCookieBridge.getCookies('https://instagram.com/');
    if (header == null || !header.contains('sessionid=')) return;

    _saving = true;
    setState(() => _status = 'Saving session…');
    try {
      await _session.saveFromCookieHeader(header);
      _done = true;
      _poll?.cancel();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      _saving = false;
      if (!mounted) return;
      setState(() => _status = 'Waiting for login… ($e)');
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect Instagram'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        children: [
          Material(
            color: AppColors.surface2,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Text(
                _status ??
                    'Sign in once. Your session stays on this device and unlocks '
                        'posts, reels, and stories.',
                style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.35),
              ),
            ),
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}

/// Opens Instagram login; returns true if a session was saved.
///
/// In-app CookieManager export is Android-only. Desktop uses Advanced cookies.txt.
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

  final result = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => InstagramLoginScreen(settings: settings),
      fullscreenDialog: true,
    ),
  );
  return result == true;
}
