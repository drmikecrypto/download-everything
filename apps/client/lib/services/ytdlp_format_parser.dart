import '../models/media.dart';

const _skipExt = {'mhtml', 'sb0', 'sb1', 'sb2'};
const _imageExt = {'jpg', 'jpeg', 'png', 'webp', 'gif'};
final _fakePageVideo = RegExp(r'/videos/[0-9a-f]{6,64}$', caseSensitive: false);

String? detectPlatform(String url) {
  final lower = url.toLowerCase();
  if (lower.contains('instagram.com') || lower.contains('instagr.am')) {
    return 'Instagram';
  }
  if (lower.contains('tiktok.com') || lower.contains('vm.tiktok.com')) {
    return 'TikTok';
  }
  if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
    return 'YouTube';
  }
  if (lower.contains('twitter.com') || lower.contains('x.com')) {
    return 'X';
  }
  return null;
}

String humanSize(int? size) {
  if (size == null || size <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = size.toDouble();
  for (var i = 0; i < units.length; i++) {
    if (value < 1024 || i == units.length - 1) {
      return '${value.toStringAsFixed(1)} ${units[i]}';
    }
    value /= 1024;
  }
  return '';
}

String formatLabel(Map<String, dynamic> fmt) {
  final parts = <String>[];
  final resolution = fmt['resolution']?.toString();
  if (resolution != null && resolution.isNotEmpty && resolution != 'audio only') {
    parts.add(resolution);
  } else if (fmt['height'] != null) {
    parts.add('${fmt['height']}p');
  }
  if (fmt['fps'] != null) {
    parts.add('${(fmt['fps'] as num).toInt()}fps');
  }
  final ext = fmt['ext']?.toString();
  if (ext != null && ext.isNotEmpty) {
    parts.add(ext.toUpperCase());
  }
  final vcodec = fmt['vcodec']?.toString();
  if (vcodec != null && vcodec != 'none' && vcodec != 'unknown') {
    parts.add(vcodec.split('.').first);
  }
  final acodec = fmt['acodec']?.toString();
  final height = fmt['height'];
  if (acodec != null && acodec != 'none' && height == null) {
    parts.add('audio');
  }
  final size = (fmt['filesize'] as num?)?.toInt() ?? (fmt['filesize_approx'] as num?)?.toInt();
  final sizeLabel = humanSize(size);
  if (sizeLabel.isNotEmpty) parts.add(sizeLabel);
  final note = fmt['format_note']?.toString();
  if (note != null && note.isNotEmpty) parts.add(note);
  if (parts.isEmpty) return fmt['format_id']?.toString() ?? 'unknown';
  return parts.join(' · ');
}

({bool isVideo, bool isAudio, bool isImage}) classifyFormat(Map<String, dynamic> fmt) {
  final vcodec = fmt['vcodec']?.toString();
  final acodec = fmt['acodec']?.toString();
  final ext = (fmt['ext']?.toString() ?? '').toLowerCase();

  var isVideo = vcodec != null && vcodec != 'none';
  var isAudio = acodec != null && acodec != 'none' && !isVideo;
  final isImage = _imageExt.contains(ext);

  if (!isVideo && !isAudio && fmt['resolution']?.toString() == 'audio only') {
    isAudio = true;
  }

  return (isVideo: isVideo, isAudio: isAudio, isImage: isImage);
}

bool _isStoryboard(Map<String, dynamic> fmt) {
  final note = (fmt['format_note']?.toString() ?? '').toLowerCase();
  final id = fmt['format_id']?.toString() ?? '';
  return note.contains('storyboard') || id.startsWith('sb');
}

bool _isFakeVideoStub(Map<String, dynamic> fmt) {
  final url = fmt['url']?.toString() ?? '';
  final protocol = (fmt['protocol']?.toString() ?? '').toLowerCase();
  final note = (fmt['format_note']?.toString() ?? '').toLowerCase();

  if (note.contains('untested')) return true;
  if (protocol.contains('m3u8') || protocol.contains('dash')) return false;
  if (_fakePageVideo.hasMatch(url)) return true;
  if (protocol == 'https' &&
      url.contains('/videos/') &&
      !url.toLowerCase().contains('xhcdn') &&
      !url.toLowerCase().contains('.mp4') &&
      !url.toLowerCase().contains('.m3u8') &&
      !url.toLowerCase().contains('cdn') &&
      !url.toLowerCase().contains('media')) {
    return true;
  }
  return false;
}

bool isDownloadableFormat(Map<String, dynamic> fmt) {
  final ext = (fmt['ext']?.toString() ?? '').toLowerCase();
  if (_skipExt.contains(ext) || _isStoryboard(fmt)) return false;
  if (fmt['url'] == null && fmt['manifest_url'] == null) return false;
  if (_isFakeVideoStub(fmt)) return false;
  final c = classifyFormat(fmt);
  return c.isVideo || c.isAudio || c.isImage;
}

List<MediaFormat> normalizeFormats(List<dynamic>? rawFormats) {
  if (rawFormats == null || rawFormats.isEmpty) return [];

  final seen = <String>{};
  final result = <MediaFormat>[];

  for (final raw in rawFormats) {
    if (raw is! Map) continue;
    final fmt = Map<String, dynamic>.from(raw);
    final formatId = fmt['format_id']?.toString() ?? '';
    if (formatId.isEmpty || seen.contains(formatId)) continue;
    if (!isDownloadableFormat(fmt)) continue;

    final c = classifyFormat(fmt);
    seen.add(formatId);
    result.add(
      MediaFormat(
        formatId: formatId,
        label: formatLabel(fmt),
        ext: fmt['ext']?.toString() ?? 'mp4',
        resolution: fmt['resolution']?.toString(),
        fps: (fmt['fps'] as num?)?.toDouble(),
        filesize: (fmt['filesize'] as num?)?.toInt(),
        filesizeApprox: (fmt['filesize_approx'] as num?)?.toInt(),
        isVideo: c.isVideo,
        isAudio: c.isAudio,
        isImage: c.isImage,
      ),
    );
  }

  result.sort((a, b) {
    final typeA = a.isVideo ? 0 : a.isAudio ? 1 : 2;
    final typeB = b.isVideo ? 0 : b.isAudio ? 1 : 2;
    if (typeA != typeB) return typeA.compareTo(typeB);
    final sizeA = a.bestSize ?? 0;
    final sizeB = b.bestSize ?? 0;
    if (sizeA != sizeB) return sizeB.compareTo(sizeA);
    return a.label.compareTo(b.label);
  });

  return _dedupeFormatVariants(result);
}

List<MediaFormat> _dedupeFormatVariants(List<MediaFormat> formats) {
  final best = <String, MediaFormat>{};
  for (final fmt in formats) {
    final base = fmt.formatId.replaceFirst(RegExp(r'-\d+$'), '');
    final key = '$base|${fmt.resolution ?? ''}|${fmt.ext}';
    final current = best[key];
    if (current == null) {
      best[key] = fmt;
      continue;
    }
    // Prefer entries that look richer (keep first high-quality label).
    if (fmt.label.length > current.label.length) {
      best[key] = fmt;
    }
  }
  return best.values.toList();
}

AnalyzeResponse analyzeResponseFromInfo(String url, Map<String, dynamic> info) {
  var formats = normalizeFormats(info['formats'] as List<dynamic>?);

  if (formats.isEmpty && info['url'] != null) {
    formats = [
      MediaFormat(
        formatId: 'best',
        label: 'Best available',
        ext: info['ext']?.toString() ?? 'mp4',
        isVideo: true,
        isAudio: false,
        isImage: false,
      ),
    ];
  }

  return AnalyzeResponse(
    url: url,
    title: info['title']?.toString() ?? info['description']?.toString(),
    thumbnail: info['thumbnail']?.toString(),
    uploader: info['uploader']?.toString() ?? info['channel']?.toString(),
    duration: (info['duration'] as num?)?.toDouble(),
    platform: detectPlatform(url) ?? info['extractor_key']?.toString(),
    formats: formats,
  );
}

/// Build yt-dlp `-f` selector for a chosen format id using dump-json info when available.
String formatSelector(String formatId, Map<String, dynamic>? info) {
  if (formatId == 'best') return 'bestvideo*+bestaudio/best';
  if (info == null) return '$formatId+bestaudio/best';

  final formats = info['formats'];
  if (formats is! List) return formatId;

  Map<String, dynamic>? fmt;
  for (final raw in formats) {
    if (raw is Map && raw['format_id']?.toString() == formatId) {
      fmt = Map<String, dynamic>.from(raw);
      break;
    }
  }
  if (fmt == null) return formatId;

  final protocol = (fmt['protocol']?.toString() ?? '').toLowerCase();
  if (protocol.contains('m3u8') || protocol.contains('dash')) return formatId;

  final c = classifyFormat(fmt);
  if (c.isVideo && !c.isAudio) return '$formatId+bestaudio/best';
  return formatId;
}

double? parseDownloadProgress(String line) {
  final match = RegExp(r'\[download\]\s+(\d+(?:\.\d+)?)%').firstMatch(line);
  if (match == null) return null;
  final value = double.tryParse(match.group(1)!);
  if (value == null) return null;
  return value.clamp(0, 100) / 100.0;
}
