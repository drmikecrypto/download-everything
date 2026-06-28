import 'package:shared_preferences/shared_preferences.dart';

const defaultApiUrl =
    'https://download-everything-api.drmikecrypto.workers.dev';

class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _apiUrlKey = 'api_url';
  static const _askSaveLocationKey = 'ask_save_location';

  String get apiUrl => _prefs.getString(_apiUrlKey) ?? defaultApiUrl;

  bool get askSaveLocation => _prefs.getBool(_askSaveLocationKey) ?? false;

  Future<void> setApiUrl(String value) async {
    final trimmed = value.trim().replaceAll(RegExp(r'/+$'), '');
    await _prefs.setString(_apiUrlKey, trimmed.isEmpty ? defaultApiUrl : trimmed);
  }

  Future<void> setAskSaveLocation(bool value) async {
    await _prefs.setBool(_askSaveLocationKey, value);
  }

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }
}
