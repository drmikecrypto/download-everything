import 'dart:convert';
import 'dart:io';

import 'package:download_everything/services/ytdlp_format_parser.dart';

/// Quick smoke: dart run tool/smoke_parse.dart [path-to-dump.json]
Future<void> main(List<String> args) async {
  final path = args.isNotEmpty ? args.first : null;
  if (path == null) {
    stderr.writeln('Usage: dart run tool/smoke_parse.dart dump.json');
    exit(64);
  }
  final info = jsonDecode(await File(path).readAsString()) as Map<String, dynamic>;
  final result = analyzeResponseFromInfo(info['webpage_url']?.toString() ?? 'url', info);
  stdout.writeln('title=${result.title}');
  stdout.writeln('platform=${result.platform}');
  stdout.writeln('formats=${result.formats.length}');
  for (final f in result.formats.take(5)) {
    stdout.writeln('  ${f.formatId} | ${f.label}');
  }
}
