// Ensures lib/app_version.dart kAppVersion matches pubspec.yaml version (before +).
// Usage (from apps/client): dart run tool/check_version.dart

import 'dart:io';

void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final pubMatch = RegExp(r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)', multiLine: true)
      .firstMatch(pubspec);
  if (pubMatch == null) {
    stderr.writeln('Could not parse version: from pubspec.yaml');
    exit(1);
  }
  final pubVersion = pubMatch.group(1)!;

  final appVersionFile = File('lib/app_version.dart').readAsStringSync();
  final appMatch =
      RegExp(r"kAppVersion\s*=\s*'([0-9]+\.[0-9]+\.[0-9]+)'").firstMatch(appVersionFile);
  if (appMatch == null) {
    stderr.writeln('Could not parse kAppVersion from lib/app_version.dart');
    exit(1);
  }
  final appVersion = appMatch.group(1)!;

  if (pubVersion != appVersion) {
    stderr.writeln(
      'Version mismatch: pubspec.yaml=$pubVersion app_version.dart=$appVersion\n'
      'Keep them in sync before release.',
    );
    exit(1);
  }

  stdout.writeln('Version OK: $pubVersion');
}
