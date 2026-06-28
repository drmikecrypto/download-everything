import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:download_everything/app.dart';
import 'package:download_everything/services/settings_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App loads home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final settings = await SettingsService.load();

    await tester.pumpWidget(DownloadEverythingApp(settings: settings));
    await tester.pumpAndSettle();

    expect(find.text('Download Everything'), findsOneWidget);
    expect(find.text('Analyze'), findsOneWidget);
  });
}
