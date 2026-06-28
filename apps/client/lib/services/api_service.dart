import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/media.dart';

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}

class ApiService {
  ApiService(this.baseUrl);

  final String baseUrl;

  Uri _uri(String path) => Uri.parse('$baseUrl$path');

  Future<Map<String, dynamic>> health() async {
    final res = await http.get(_uri('/health')).timeout(const Duration(seconds: 15));
    if (res.statusCode != 200) {
      throw ApiException('Server returned ${res.statusCode}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<AnalyzeResponse> analyze(String url) async {
    final res = await http
        .post(
          _uri('/analyze'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'url': url}),
        )
        .timeout(const Duration(seconds: 90));

    if (res.statusCode != 200) {
      throw ApiException(_parseError(res.body) ?? 'Analysis failed (${res.statusCode})');
    }

    return AnalyzeResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>);
  }

  String downloadEndpoint(String mediaUrl, String formatId) {
    return _uri('/download')
        .replace(queryParameters: {'url': mediaUrl, 'format_id': formatId})
        .toString();
  }

  String? _parseError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'];
      if (detail is String) return detail;
      if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first['msg'] != null) return first['msg'].toString();
      }
    } catch (_) {}
    return null;
  }
}
