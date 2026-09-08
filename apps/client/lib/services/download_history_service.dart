import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class HistoryEntry {
  const HistoryEntry({
    required this.url,
    required this.title,
    required this.path,
    required this.savedAt,
  });

  final String url;
  final String title;
  final String path;
  final DateTime savedAt;

  Map<String, dynamic> toJson() => {
        'url': url,
        'title': title,
        'path': path,
        'savedAt': savedAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      url: json['url'] as String? ?? '',
      title: json['title'] as String? ?? 'download',
      path: json['path'] as String? ?? '',
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Local-only download history (SharedPreferences).
class DownloadHistoryService {
  DownloadHistoryService(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'download_history_v1';
  static const _maxEntries = 100;

  List<HistoryEntry> load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list
          .whereType<Map>()
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> add({
    required String url,
    required String title,
    required String path,
  }) async {
    final entries = load().toList();
    entries.insert(
      0,
      HistoryEntry(
        url: url,
        title: title,
        path: path,
        savedAt: DateTime.now(),
      ),
    );
    while (entries.length > _maxEntries) {
      entries.removeLast();
    }
    await _prefs.setString(
      _key,
      jsonEncode(entries.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
