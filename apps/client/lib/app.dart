import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'theme/app_theme.dart';

class DownloadEverythingApp extends StatelessWidget {
  const DownloadEverythingApp({super.key, required this.settings});

  final SettingsService settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Download Everything',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: HomeScreen(settings: settings),
    );
  }
}
