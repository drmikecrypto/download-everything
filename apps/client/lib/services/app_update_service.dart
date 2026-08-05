import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app_version.dart';

/// Quiet check against GitHub Releases for a newer `app-v*` tag.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.latestVersion,
    required this.tagName,
    required this.releaseUrl,
  });

  final String latestVersion;
  final String tagName;
  final String releaseUrl;
}

class AppUpdateService {
  static const _owner = 'drmikecrypto';
  static const _repo = 'download-everything';
  static final _tagPattern = RegExp(r'^app-v(\d+\.\d+\.\d+)$');

  /// Returns update info when a newer semver release exists; otherwise null.
  /// Network / parse failures are swallowed (button stays hidden).
  Future<AppUpdateInfo?> checkForUpdate({String? localVersion}) async {
    try {
      final local = _parseSemver(localVersion ?? kAppVersion);
      if (local == null) return null;

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
        final tag = raw['tag_name']?.toString() ?? '';
        final match = _tagPattern.firstMatch(tag);
        if (match == null) continue;
        final version = match.group(1)!;
        final parts = _parseSemver(version);
        if (parts == null) continue;
        if (bestParts == null || _compareSemver(parts, bestParts) > 0) {
          bestParts = parts;
          best = AppUpdateInfo(
            latestVersion: version,
            tagName: tag,
            releaseUrl: raw['html_url']?.toString() ??
                'https://github.com/$_owner/$_repo/releases/tag/$tag',
          );
        }
      }

      if (best == null || bestParts == null) return null;
      if (_compareSemver(bestParts, local) <= 0) return null;
      return best;
    } catch (_) {
      return null;
    }
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
