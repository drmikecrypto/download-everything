import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  SettingsService(this._prefs);

  final SharedPreferences _prefs;

  static const _askSaveLocationKey = 'ask_save_location';
  static const _cookiesPathKey = 'cookies_path';
  static const _writeSubsKey = 'write_subs';
  static const _sponsorBlockKey = 'sponsor_block';
  static const _allowPlaylistKey = 'allow_playlist';

  bool get askSaveLocation => _prefs.getBool(_askSaveLocationKey) ?? false;

  bool get writeSubs => _prefs.getBool(_writeSubsKey) ?? false;

  bool get sponsorBlock => _prefs.getBool(_sponsorBlockKey) ?? false;

  bool get allowPlaylist => _prefs.getBool(_allowPlaylistKey) ?? true;

  String? get cookiesPath {
    final value = _prefs.getString(_cookiesPathKey);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  Future<void> setAskSaveLocation(bool value) async {
    await _prefs.setBool(_askSaveLocationKey, value);
  }

  Future<void> setWriteSubs(bool value) async {
    await _prefs.setBool(_writeSubsKey, value);
  }

  Future<void> setSponsorBlock(bool value) async {
    await _prefs.setBool(_sponsorBlockKey, value);
  }

  Future<void> setAllowPlaylist(bool value) async {
    await _prefs.setBool(_allowPlaylistKey, value);
  }

  Future<void> setCookiesPath(String? value) async {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      await _prefs.remove(_cookiesPathKey);
    } else {
      await _prefs.setString(_cookiesPathKey, trimmed);
    }
  }

  /// App-private Netscape cookies path (readable by Android yt-dlp).
  Future<String> cookiesStoragePath() async {
    final docs = await getApplicationDocumentsDirectory();
    return p.join(docs.path, 'cookies', 'cookies.txt');
  }

  /// Copies picker content into app storage and persists that path.
  Future<String> importCookiesFile({String? sourcePath, List<int>? bytes}) async {
    final destPath = await cookiesStoragePath();
    final dest = File(destPath);
    await dest.parent.create(recursive: true);

    if (bytes != null && bytes.isNotEmpty) {
      await dest.writeAsBytes(bytes, flush: true);
    } else if (sourcePath != null && sourcePath.trim().isNotEmpty) {
      final src = File(sourcePath);
      if (!await src.exists()) {
        throw StateError('Selected cookies file is not readable on this device.');
      }
      await src.copy(destPath);
    } else {
      throw StateError('No cookies file data to import.');
    }

    await setCookiesPath(destPath);
    return destPath;
  }

  /// Deletes the stored cookies file (if present) and clears prefs.
  Future<void> clearCookies() async {
    final path = cookiesPath;
    if (path != null) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Best-effort delete; still clear the preference.
      }
    }
    final stored = File(await cookiesStoragePath());
    if (await stored.exists()) {
      try {
        await stored.delete();
      } catch (_) {}
    }
    await setCookiesPath(null);
  }

  static Future<SettingsService> load() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }
}
