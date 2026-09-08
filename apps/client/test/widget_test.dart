import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:download_everything/app.dart';
import 'package:download_everything/services/download_history_service.dart';
import 'package:download_everything/services/download_queue_service.dart';
import 'package:download_everything/services/settings_service.dart';
import 'package:download_everything/services/ytdlp_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs);
    final engine = YtdlpEngine();
    final history = DownloadHistoryService(prefs);
    final queue = DownloadQueueService(
      engine: engine,
      settings: settings,
      history: history,
    );

    await tester.pumpWidget(
      DownloadEverythingApp(
        settings: settings,
        engine: engine,
        history: history,
        queue: queue,
      ),
    );
    await tester.pump();

    expect(find.text('Download Everything'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
  });
}
