import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _askSaveLocationKey = 'ask_save_location';
  static const _cookiesPathKey = 'cookies_path';

  bool get askSaveLocation => _prefs.getBool(_askSaveLocationKey) ?? false;

  String? get cookiesPath {
    final value = _prefs.getString(_cookiesPathKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> setAskSaveLocation(bool value) async {
    await _prefs.setBool(_askSaveLocationKey, value);
  }

  Future<void> setCookiesPath(String? value) async {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _prefs.remove(_cookiesPathKey);
    } else {
      await _prefs.setString(_cookiesPathKey, trimmed);
    }
  }

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }
}
