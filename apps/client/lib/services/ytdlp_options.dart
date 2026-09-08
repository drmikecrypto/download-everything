/// Shared yt-dlp CLI flags for site compatibility (desktop Process path).
const kMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

const kInstagramAppId = '936619743392459';

bool isInstagramUrl(String url) {
  final lower = url.toLowerCase();
  return lower.contains('instagram.com') || lower.contains('instagr.am');
}

const kInstagramCookiesTip =
    'Tip: Sign in to Instagram in the app (Home will prompt, or use Settings → Connect Instagram). '
    'Your session stays on this device and unlocks posts, reels, and stories.';

/// Appends a cookies tip when the URL or error looks Instagram/auth related.
String appendInstagramCookiesTip(String url, String raw) {
  final lower = raw.toLowerCase();
  final needsTip = isInstagramUrl(url) ||
      url.toLowerCase().contains('/stories/') ||
      lower.contains('empty media') ||
      lower.contains('impersonat') ||
      lower.contains('login') ||
      lower.contains('cookie') ||
      lower.contains('private');
  if (!needsTip) return raw;
  if (raw.contains(kInstagramCookiesTip)) return raw;
  return '$raw\n\n$kInstagramCookiesTip';
}

/// Common analyze/download flags applied on every request.
List<String> commonYtdlpArgs(
  String url, {
  bool allowPlaylist = false,
  bool writeSubs = false,
  bool sponsorBlock = false,
}) {
  final args = <String>[
    if (!allowPlaylist) '--no-playlist',
    '--no-warnings',
  ];
  // Custom UA breaks Instagram (empty media / 403); let yt-dlp choose headers there.
  if (!isInstagramUrl(url)) {
    args.addAll(['--user-agent', kMobileUserAgent]);
  } else {
    args.addAll(['--extractor-args', 'instagram:app_id=$kInstagramAppId']);
  }
  if (writeSubs) {
    args.addAll([
      '--write-subs',
      '--write-auto-subs',
      '--embed-subs',
      '--sub-langs',
      'en.*,en',
    ]);
  }
  if (sponsorBlock) {
    args.addAll(['--sponsorblock-remove', 'default']);
  }
  return args;
}
