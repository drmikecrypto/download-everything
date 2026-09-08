import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/download_history_service.dart';
import 'services/download_queue_service.dart';
import 'services/settings_service.dart';
import 'services/ytdlp_engine.dart';
import 'theme/app_theme.dart';

class DownloadEverythingApp extends StatelessWidget {
  const DownloadEverythingApp({
    super.key,
    required this.settings,
    required this.engine,
    required this.history,
    required this.queue,
  });

  final SettingsService settings;
  final YtdlpEngine engine;
  final DownloadHistoryService history;
  final DownloadQueueService queue;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Download Everything',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(
        settings: settings,
        engine: engine,
        history: history,
        queue: queue,
      ),
    );
  }
}
