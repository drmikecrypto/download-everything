import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/browser_bridge_service.dart';
import 'services/download_history_service.dart';
import 'services/download_queue_service.dart';
import 'services/settings_service.dart';
import 'services/ytdlp_engine.dart';
import 'app_brand.dart';
import 'theme/app_theme.dart';

class DefApp extends StatelessWidget {
  const DefApp({
    super.key,
    required this.settings,
    required this.engine,
    required this.history,
    required this.queue,
    required this.bridge,
  });

  final SettingsService settings;
  final YtdlpEngine engine;
  final DownloadHistoryService history;
  final DownloadQueueService queue;
  final BrowserBridgeService bridge;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: kAppName,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(
        settings: settings,
        engine: engine,
        history: history,
        queue: queue,
        bridge: bridge,
      ),
    );
  }
}

/// Backward-compatible alias.
typedef DownloadEverythingApp = DefApp;
