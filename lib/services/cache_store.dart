import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CacheEntry {
  final Object data;
  final DateTime cachedAt;

  const CacheEntry({
    required this.data,
    required this.cachedAt,
  });
}

class ApiCacheStore {
  ApiCacheStore(this._prefs);

  static const String _prefix = 'api_cache_v1_';

  final SharedPreferences _prefs;

  CacheEntry? read({
    required String scope,
    required String baseUrl,
    required String endpoint,
    Map<String, Object?>? params,
  }) {
    final raw = _prefs.getString(
      _cacheKey(
        scope: scope,
        baseUrl: baseUrl,
        endpoint: endpoint,
        params: params,
      ),
    );
    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = json.decode(raw);
      if (decoded is! Map) {
        return null;
      }

      final cachedAtRaw = decoded['cached_at']?.toString();
      final cachedAt =
          cachedAtRaw == null ? null : DateTime.tryParse(cachedAtRaw);
      final data = decoded['data'];
      if (cachedAt == null || (data is! Map && data is! List)) {
        return null;
      }

      return CacheEntry(
        data: data as Object,
        cachedAt: cachedAt,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> write({
    required String scope,
    required String baseUrl,
    required String endpoint,
    Map<String, Object?>? params,
    required Object data,
  }) async {
    if (data is! Map && data is! List) {
      return;
    }

    await _prefs.setString(
      _cacheKey(
        scope: scope,
        baseUrl: baseUrl,
        endpoint: endpoint,
        params: params,
      ),
      json.encode({
        'cached_at': DateTime.now().toIso8601String(),
        'data': data,
      }),
    );
  }

  Future<int> clearScope(String scope) async {
    final keys = _prefs
        .getKeys()
        .where((key) => key.startsWith(_scopePrefix(scope)))
        .toList(growable: false);
    for (final key in keys) {
      await _prefs.remove(key);
    }
    return keys.length;
  }

  Future<int> clearAll() async {
    final keys = _prefs
        .getKeys()
        .where((key) => key.startsWith(_prefix))
        .toList(growable: false);
    for (final key in keys) {
      await _prefs.remove(key);
    }
    return keys.length;
  }

  int countScope(String scope) {
    return _prefs
        .getKeys()
        .where((key) => key.startsWith(_scopePrefix(scope)))
        .length;
  }

  int countAll() {
    return _prefs.getKeys().where((key) => key.startsWith(_prefix)).length;
  }

  String _cacheKey({
    required String scope,
    required String baseUrl,
    required String endpoint,
    Map<String, Object?>? params,
  }) {
    final descriptor = json.encode({
      'base_url': baseUrl,
      'endpoint': endpoint,
      'params': _normalizeParams(params),
    });
    return '${_scopePrefix(scope)}${base64Url.encode(utf8.encode(descriptor))}';
  }

  String _scopePrefix(String scope) {
    return '$_prefix${base64Url.encode(utf8.encode(scope))}::';
  }

  Map<String, String> _normalizeParams(Map<String, Object?>? params) {
    if (params == null || params.isEmpty) {
      return const {};
    }

    final entries = params.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));

    final normalized = <String, String>{};
    for (final entry in entries) {
      final value = entry.value;
      if (value == null) {
        continue;
      }
      final text = value.toString();
      if (text.isNotEmpty) {
        normalized[entry.key] = text;
      }
    }
    return normalized;
  }
}
