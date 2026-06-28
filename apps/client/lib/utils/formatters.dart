String formatDuration(double? seconds) {
  if (seconds == null || seconds <= 0) return '';
  final m = seconds ~/ 60;
  final s = (seconds % 60).floor();
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const units = ['B', 'KB', 'MB', 'GB'];
  var value = bytes.toDouble();
  var i = 0;
  while (value >= 1024 && i < units.length - 1) {
    value /= 1024;
    i++;
  }
  return '${value.toStringAsFixed(value >= 10 || i == 0 ? 0 : 1)} ${units[i]}';
}

String sanitizeFilename(String name) {
  final cleaned = name
      .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  if (cleaned.isEmpty) return 'download';
  return cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned;
}
