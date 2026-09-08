import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'services/download_history_service.dart';
import 'services/download_queue_service.dart';
import 'services/settings_service.dart';
import 'services/ytdlp_engine.dart';

Future<void> main() async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Prefer packaged font assets; never block/crash startup on network font fetch.
    GoogleFonts.config.allowRuntimeFetching = false;

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      if (kDebugMode) {
        debugPrint(details.toString());
      }
    };

    try {
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    } catch (_) {
      // Older OEM builds can reject edge-to-edge; UI still works without it.
    }

    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs);
    final engine = YtdlpEngine();
    final history = DownloadHistoryService(prefs);
    final queue = DownloadQueueService(
      engine: engine,
      settings: settings,
      history: history,
    );
    runApp(
      DownloadEverythingApp(
        settings: settings,
        engine: engine,
        history: history,
        queue: queue,
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught zone error: $error\n$stack');
  });
}
