import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'services/settings_service.dart';
import 'services/ytdlp_engine.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  final settings = await SettingsService.load();
  final engine = YtdlpEngine();
  runApp(DownloadEverythingApp(settings: settings, engine: engine));
}
