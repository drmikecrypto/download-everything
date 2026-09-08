import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../app_version.dart';

/// Quiet check against GitHub Releases for a newer `app-v*` tag.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releaseUrl,
    this.downloadUrl,
  });

  final String latestVersion;
  final String tagName;
  final String releaseUrl;

  /// Direct installer/APK URL for this platform when the release has a matching asset.
  final String? downloadUrl;

  /// Prefer platform asset; otherwise the release page.
  String get openUrl => downloadUrl ?? releaseUrl;
}

class AppUpdateService {
  static const _owner = 'drmikecrypto';
  static const _repo = 'download-everything';
  static const _dismissedKey = 'dismissed_update_version';
  static final _tagPattern = RegExp(r'^app-v(\d+\.\d+\.\d+)$');

  /// Returns update info when a newer semver release exists; otherwise null.
  /// Network / parse failures are swallowed (button stays hidden).
  /// Set [includeDismissed] to true to ignore a previously dismissed banner version.
  Future<AppUpdateInfo?> checkForUpdate({
    String? localVersion,
    bool includeDismissed = false,
  }) async {
    try {
      final local = _parseSemver(localVersion ?? kAppVersion);
      if (local == null) return null;

      // Prefer /releases/latest (single request); fall back to list for odd tag shapes.
      var best = await _fetchLatestRelease();
      best ??= await _fetchBestFromList();
      if (best == null) return null;

      final bestParts = _parseSemver(best.latestVersion);
      if (bestParts == null) return null;
      if (_compareSemver(bestParts, local) <= 0) return null;

      if (!includeDismissed) {
        final prefs = await SharedPreferences.getInstance();
        final dismissed = prefs.getString(_dismissedKey);
        if (dismissed == best.latestVersion) return null;
      }
      return best;
    } catch (_) {
      return null;
    }
  }

  /// Hide the home banner for this version until a newer release appears.
  Future<void> dismiss(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dismissedKey, version);
  }

  Future<AppUpdateInfo?> _fetchLatestRelease() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$_owner/$_repo/releases/latest',
    );
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'download-everything-app',
      },
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;
    final raw = jsonDecode(response.body);
    if (raw is! Map) return null;
    if (raw['draft'] == true || raw['prerelease'] == true) return null;
    return _fromReleaseMap(raw);
  }

  Future<AppUpdateInfo?> _fetchBestFromList() async {
    final uri = Uri.https(
      'api.github.com',
      '/repos/$_owner/$_repo/releases',
      {'per_page': '15'},
    );
    final response = await http.get(
      uri,
      headers: const {
        'Accept': 'application/vnd.github+json',
        'User-Agent': 'download-everything-app',
      },
    ).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) return null;

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return null;

    AppUpdateInfo? best;
    List<int>? bestParts;
    for (final raw in decoded) {
      if (raw is! Map) continue;
      if (raw['draft'] == true || raw['prerelease'] == true) continue;
      final info = _fromReleaseMap(raw);
      if (info == null) continue;
      final parts = _parseSemver(info.latestVersion);
      if (parts == null) continue;
      if (bestParts == null || _compareSemver(parts, bestParts) > 0) {
        bestParts = parts;
        best = info;
      }
    }
    return best;
  }

  static AppUpdateInfo? _fromReleaseMap(Map raw) {
    final tag = raw['tag_name']?.toString() ?? '';
    final match = _tagPattern.firstMatch(tag);
    if (match == null) return null;
    final version = match.group(1)!;
    return AppUpdateInfo(
      latestVersion: version,
      tagName: tag,
      releaseUrl: raw['html_url']?.toString() ??
          'https://github.com/$_owner/$_repo/releases/tag/$tag',
      downloadUrl: _platformAssetUrl(raw['assets']),
    );
  }

  static String? _platformAssetUrl(Object? assetsRaw) {
    if (assetsRaw is! List) return null;
    final needles = _assetNameNeedles();
    if (needles.isEmpty) return null;

    for (final raw in assetsRaw) {
      if (raw is! Map) continue;
      final name = (raw['name']?.toString() ?? '').toLowerCase();
      final url = raw['browser_download_url']?.toString();
      if (url == null || url.isEmpty) continue;
      if (needles.any(name.contains)) return url;
    }
    return null;
  }

  static List<String> _assetNameNeedles() {
    if (Platform.isAndroid) return const ['android', '.apk'];
    if (Platform.isWindows) return const ['windows'];
    if (Platform.isLinux) return const ['linux'];
    if (Platform.isMacOS) return const ['macos', 'darwin'];
    return const [];
  }

  static List<int>? _parseSemver(String version) {
    final cleaned = version.trim();
    final parts = cleaned.split('.');
    if (parts.length != 3) return null;
    final nums = <int>[];
    for (final part in parts) {
      final n = int.tryParse(part);
      if (n == null) return null;
      nums.add(n);
    }
    return nums;
  }

  /// Negative if a < b, zero if equal, positive if a > b.
  static int _compareSemver(List<int> a, List<int> b) {
    for (var i = 0; i < 3; i++) {
      final diff = a[i] - b[i];
      if (diff != 0) return diff;
    }
    return 0;
  }
}
