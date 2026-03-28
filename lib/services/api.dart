import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class ApiService {
  static const Duration _timeout = Duration(seconds: 15);

  static String defaultBaseUrl() {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8087';
    }
    return 'http://127.0.0.1:8087';
  }

  static String normalizeBaseUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return defaultBaseUrl();
    }

    final withScheme = trimmed.contains('://') ? trimmed : 'http://$trimmed';
    final uri = Uri.parse(withScheme);

    if (uri.hasPort) {
      return uri.toString().replaceAll(RegExp(r'/$'), '');
    }

    return uri.replace(port: 8087).toString().replaceAll(RegExp(r'/$'), '');
  }

  static Uri buildUri(
    String baseUrl,
    String endpoint, {
    Map<String, Object?>? params,
  }) {
    final base = Uri.parse(normalizeBaseUrl(baseUrl));
    final uri = base.resolve(endpoint);
    if (params == null || params.isEmpty) {
      return uri;
    }

    final query = <String, String>{};
    for (final entry in params.entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      final stringValue = value.toString();
      if (stringValue.isNotEmpty) {
        query[entry.key] = stringValue;
      }
    }

    return uri.replace(queryParameters: query.isEmpty ? null : query);
  }

  static Map<String, String> defaultRange([int days = 13]) {
    final now = DateTime.now();
    final past = now.subtract(Duration(days: days));
    return {
      'from_date': _formatDate(past),
      'to_date': _formatDate(now),
    };
  }

  static String formatDate(DateTime date) => _formatDate(date);

  static Future<Map<String, dynamic>> fetchJson(
    String baseUrl,
    String endpoint, {
    Map<String, Object?>? params,
  }) async {
    final uri = buildUri(baseUrl, endpoint, params: params);
    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
      return _decodeMap(response);
    } on SocketException catch (error) {
      throw ApiException('네트워크 연결 실패: $error');
    } on HttpException catch (error) {
      throw ApiException('HTTP 예외: $error');
    } on FormatException catch (error) {
      throw ApiException('응답 파싱 실패: $error');
    }
  }

  static Future<List<dynamic>> fetchJsonList(
    String baseUrl,
    String endpoint, {
    Map<String, Object?>? params,
  }) async {
    final uri = buildUri(baseUrl, endpoint, params: params);
    try {
      final response = await http
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          'HTTP ${response.statusCode}: ${_decodeErrorMessage(response)}',
        );
      }

      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is List<dynamic>) {
        return decoded;
      }
      throw const ApiException('예상과 다른 응답 형식입니다.');
    } on SocketException catch (error) {
      throw ApiException('네트워크 연결 실패: $error');
    } on HttpException catch (error) {
      throw ApiException('HTTP 예외: $error');
    } on FormatException catch (error) {
      throw ApiException('응답 파싱 실패: $error');
    }
  }

  static Future<Map<String, dynamic>> postJson(
    String baseUrl,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final uri = buildUri(baseUrl, endpoint);
    try {
      final response = await http
          .post(
            uri,
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: body != null ? json.encode(body) : null,
          )
          .timeout(_timeout);
      return _decodeMap(response);
    } on SocketException catch (error) {
      throw ApiException('네트워크 연결 실패: $error');
    } on HttpException catch (error) {
      throw ApiException('HTTP 예외: $error');
    } on FormatException catch (error) {
      throw ApiException('응답 파싱 실패: $error');
    }
  }

  static Map<String, dynamic> _decodeMap(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'HTTP ${response.statusCode}: ${_decodeErrorMessage(response)}',
      );
    }

    final decoded = json.decode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw const ApiException('예상과 다른 응답 형식입니다.');
  }

  static String _decodeErrorMessage(http.Response response) {
    try {
      final decoded = json.decode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return (decoded['detail'] ??
                decoded['error'] ??
                response.reasonPhrase ??
                '오류')
            .toString();
      }
    } catch (_) {
      // Ignore secondary parse failures and use the HTTP reason phrase.
    }
    return response.reasonPhrase ?? '오류';
  }

  static String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}
