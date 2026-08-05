/// Shared yt-dlp CLI flags for site compatibility (desktop Process path).
const kMobileUserAgent =
    'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/131.0.0.0 Mobile Safari/537.36';

const kInstagramAppId = '936619743392459';

/// Common analyze/download flags applied on every request.
List<String> commonYtdlpArgs(String url) {
  final args = <String>[
    '--no-playlist',
    '--no-warnings',
    '--user-agent',
    kMobileUserAgent,
  ];
  final lower = url.toLowerCase();
  if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
    args.addAll(['--extractor-args', 'instagram:app_id=$kInstagramAppId']);
  }
  return args;
}
