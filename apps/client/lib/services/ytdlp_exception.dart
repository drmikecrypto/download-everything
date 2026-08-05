class YtdlpException implements Exception {
  YtdlpException(this.message);
  final String message;

  @override
  String toString() => message;
}
