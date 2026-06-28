class MediaFormat {
  const MediaFormat({
    required this.formatId,
    required this.label,
    required this.ext,
    this.resolution,
    this.fps,
    this.filesize,
    this.filesizeApprox,
    required this.isVideo,
    required this.isAudio,
    required this.isImage,
  });

  final String formatId;
  final String label;
  final String ext;
  final String? resolution;
  final double? fps;
  final int? filesize;
  final int? filesizeApprox;
  final bool isVideo;
  final bool isAudio;
  final bool isImage;

  factory MediaFormat.fromJson(Map<String, dynamic> json) {
    return MediaFormat(
      formatId: json['format_id'] as String,
      label: json['label'] as String,
      ext: json['ext'] as String? ?? 'bin',
      resolution: json['resolution'] as String?,
      fps: (json['fps'] as num?)?.toDouble(),
      filesize: json['filesize'] as int?,
      filesizeApprox: json['filesize_approx'] as int?,
      isVideo: json['is_video'] as bool? ?? false,
      isAudio: json['is_audio'] as bool? ?? false,
      isImage: json['is_image'] as bool? ?? false,
    );
  }

  String get typeLabel {
    if (isVideo) return 'Video';
    if (isAudio) return 'Audio';
    if (isImage) return 'Image';
    return 'Media';
  }

  int? get bestSize => filesize ?? filesizeApprox;
}

class AnalyzeResponse {
  const AnalyzeResponse({
    required this.url,
    this.title,
    this.thumbnail,
    this.uploader,
    this.duration,
    this.platform,
    required this.formats,
    this.error,
  });

  final String url;
  final String? title;
  final String? thumbnail;
  final String? uploader;
  final double? duration;
  final String? platform;
  final List<MediaFormat> formats;
  final String? error;

  factory AnalyzeResponse.fromJson(Map<String, dynamic> json) {
    final formatsJson = json['formats'] as List<dynamic>? ?? [];
    return AnalyzeResponse(
      url: json['url'] as String,
      title: json['title'] as String?,
      thumbnail: json['thumbnail'] as String?,
      uploader: json['uploader'] as String?,
      duration: (json['duration'] as num?)?.toDouble(),
      platform: json['platform'] as String?,
      formats: formatsJson
          .map((e) => MediaFormat.fromJson(e as Map<String, dynamic>))
          .toList(),
      error: json['error'] as String?,
    );
  }
}
