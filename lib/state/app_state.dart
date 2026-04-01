import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/cache_store.dart';

class CachedMapResult {
  final Map<String, dynamic> data;
  final bool fromCache;
  final DateTime? cachedAt;

  const CachedMapResult({
    required this.data,
    required this.fromCache,
    required this.cachedAt,
  });
}

class CachedListResult {
  final List<dynamic> data;
  final bool fromCache;
  final DateTime? cachedAt;

  const CachedListResult({
    required this.data,
    required this.fromCache,
    required this.cachedAt,
  });
}

class AppState extends ChangeNotifier {
  AppState() : _apiBaseUrl = ApiService.defaultBaseUrl();

  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _sessionCookieKey = 'auth_session_cookie';
  static const String _csrfTokenKey = 'auth_csrf_token';
  static const String _loginIdKey = 'auth_login_id';
  static const String _roleKey = 'auth_role';
  static const String _setupRequiredKey = 'auth_setup_required';
  static const String _bootstrapConfiguredKey = 'auth_bootstrap_configured';

  String _apiBaseUrl;
  late SharedPreferences _prefs;
  late ApiCacheStore _cacheStore;
  bool _isInitializing = true;
  bool _authenticated = false;
  bool _offlineMode = false;
  bool _setupRequired = false;
  bool _bootstrapConfigured = false;
  String? _sessionCookie;
  String? _csrfToken;
  String? _loginId;
  String? _role;
  DateTime? _lastSessionSyncAt;
  int _cacheEntryCount = 0;

  String get apiBaseUrl => _apiBaseUrl;
  bool get isInitializing => _isInitializing;
  bool get isAuthenticated => _authenticated;
  bool get offlineMode => _offlineMode;
  bool get setupRequired => _setupRequired;
  bool get bootstrapConfigured => _bootstrapConfigured;
  String? get loginId => _loginId;
  String? get role => _role;
  DateTime? get lastSessionSyncAt => _lastSessionSyncAt;
  int get cacheEntryCount => _cacheEntryCount;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _cacheStore = ApiCacheStore(_prefs);

    final savedBaseUrl = _prefs.getString(_apiBaseUrlKey);
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      _apiBaseUrl = ApiService.normalizeBaseUrl(savedBaseUrl);
    }

    _sessionCookie = _prefs.getString(_sessionCookieKey);
    _csrfToken = _prefs.getString(_csrfTokenKey);
    _loginId = _prefs.getString(_loginIdKey);
    _role = _prefs.getString(_roleKey);
    _setupRequired = _prefs.getBool(_setupRequiredKey) ?? false;
    _bootstrapConfigured = _prefs.getBool(_bootstrapConfiguredKey) ?? false;
    _refreshCacheCount();

    if (_hasPersistedSession) {
      _authenticated = true;
      _offlineMode = true;
    }

    try {
      await refreshSession(notify: false);
    } catch (_) {
      // Keep the persisted session for offline cached browsing.
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<void> refreshSession({bool notify = true}) async {
    try {
      final response = await ApiService.fetchJson(
        _apiBaseUrl,
        '/api/auth/session',
        sessionCookie: _sessionCookie,
      );
      final payload = response.data;
      _setupRequired = payload['setup_required'] == true;
      _bootstrapConfigured = payload['bootstrap_configured'] == true;
      _lastSessionSyncAt = DateTime.now();

      if (response.sessionCookie != null &&
          response.sessionCookie!.isNotEmpty) {
        _sessionCookie = response.sessionCookie;
      }

      final user = payload['user'];
      if (payload['authenticated'] == true && user is Map) {
        _authenticated = true;
        _offlineMode = false;
        _loginId = user['login_id']?.toString();
        _role = user['role']?.toString();
        _csrfToken = payload['csrf_token']?.toString();
        await _persistAuthState();
      } else {
        await _clearAuthState(preserveSetupFlags: true);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearAuthState(preserveSetupFlags: true);
      } else if (_hasPersistedSession) {
        _authenticated = true;
        _offlineMode = true;
      }
      rethrow;
    } finally {
      await _persistSetupState();
      _refreshCacheCount();
      if (notify) {
        notifyListeners();
      }
    }
  }

  Future<void> login(String loginId, String password) async {
    final trimmedId = loginId.trim();
    if (trimmedId.isEmpty || password.isEmpty) {
      throw const ApiException('아이디와 비밀번호를 입력하세요.');
    }

    final response = await ApiService.postJson(
      _apiBaseUrl,
      '/api/auth/login',
      body: {
        'login_id': trimmedId,
        'password': password,
      },
      includeCsrfToken: false,
    );

    final user = response.data['user'];
    if (user is! Map ||
        response.sessionCookie == null ||
        response.sessionCookie!.isEmpty) {
      throw const ApiException('로그인 응답이 올바르지 않습니다.');
    }

    _authenticated = true;
    _offlineMode = false;
    _sessionCookie = response.sessionCookie;
    _csrfToken = response.data['csrf_token']?.toString();
    _loginId = user['login_id']?.toString();
    _role = user['role']?.toString();
    _setupRequired = false;
    _lastSessionSyncAt = DateTime.now();
    await _persistAuthState();
    await _persistSetupState();
    _refreshCacheCount();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _postJsonWithAuth('/api/auth/logout');
    } catch (_) {
      // Clear the local session even if the server is unreachable.
    }

    final scope = _cacheScope;
    await _clearAuthState();
    await _cacheStore.clearScope(scope);
    _refreshCacheCount();
    notifyListeners();
  }

  Future<void> updateApiBaseUrl(String value) async {
    _apiBaseUrl = ApiService.normalizeBaseUrl(value);
    await _prefs.setString(_apiBaseUrlKey, _apiBaseUrl);
    await _clearAuthState(preserveSetupFlags: false);
    _refreshCacheCount();
    notifyListeners();
  }

  Future<void> resetApiBaseUrl() async {
    _apiBaseUrl = ApiService.defaultBaseUrl();
    await _prefs.remove(_apiBaseUrlKey);
    await _clearAuthState(preserveSetupFlags: false);
    _refreshCacheCount();
    notifyListeners();
  }

  Future<int> clearCache() async {
    final removed = await _cacheStore.clearAll();
    _refreshCacheCount();
    notifyListeners();
    return removed;
  }

  Future<CachedMapResult> fetchJson(
    String endpoint, {
    Map<String, Object?>? params,
    Duration cacheTtl = const Duration(minutes: 15),
    bool allowStaleOnError = true,
  }) async {
    final cacheEntry = _cacheStore.read(
      scope: _cacheScope,
      baseUrl: _apiBaseUrl,
      endpoint: endpoint,
      params: params,
    );

    try {
      final response = await ApiService.fetchJson(
        _apiBaseUrl,
        endpoint,
        params: params,
        sessionCookie: _sessionCookie,
      );
      _offlineMode = false;
      if (response.sessionCookie != null &&
          response.sessionCookie!.isNotEmpty) {
        _sessionCookie = response.sessionCookie;
        await _persistAuthState();
      }
      await _cacheStore.write(
        scope: _cacheScope,
        baseUrl: _apiBaseUrl,
        endpoint: endpoint,
        params: params,
        data: response.data,
      );
      _refreshCacheCount();
      return CachedMapResult(
        data: response.data,
        fromCache: false,
        cachedAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      await _handleAuthError(error);
      if (allowStaleOnError && cacheEntry != null && cacheEntry.data is Map) {
        _offlineMode = true;
        notifyListeners();
        return CachedMapResult(
          data: Map<String, dynamic>.from(cacheEntry.data as Map),
          fromCache: true,
          cachedAt: cacheEntry.cachedAt,
        );
      }
      rethrow;
    }
  }

  Future<CachedListResult> fetchJsonList(
    String endpoint, {
    Map<String, Object?>? params,
    Duration cacheTtl = const Duration(minutes: 15),
    bool allowStaleOnError = true,
  }) async {
    final cacheEntry = _cacheStore.read(
      scope: _cacheScope,
      baseUrl: _apiBaseUrl,
      endpoint: endpoint,
      params: params,
    );

    try {
      final response = await ApiService.fetchJsonList(
        _apiBaseUrl,
        endpoint,
        params: params,
        sessionCookie: _sessionCookie,
      );
      _offlineMode = false;
      if (response.sessionCookie != null &&
          response.sessionCookie!.isNotEmpty) {
        _sessionCookie = response.sessionCookie;
        await _persistAuthState();
      }
      await _cacheStore.write(
        scope: _cacheScope,
        baseUrl: _apiBaseUrl,
        endpoint: endpoint,
        params: params,
        data: response.data,
      );
      _refreshCacheCount();
      return CachedListResult(
        data: response.data,
        fromCache: false,
        cachedAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      await _handleAuthError(error);
      if (allowStaleOnError && cacheEntry != null && cacheEntry.data is List) {
        _offlineMode = true;
        notifyListeners();
        return CachedListResult(
          data: List<dynamic>.from(cacheEntry.data as List),
          fromCache: true,
          cachedAt: cacheEntry.cachedAt,
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> postJson(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final response = await _postJsonWithAuth(endpoint, body: body);
    _offlineMode = false;
    return response.data;
  }

  Future<ApiResponse<Map<String, dynamic>>> _postJsonWithAuth(
    String endpoint, {
    Map<String, dynamic>? body,
    bool allowRetry = true,
  }) async {
    try {
      final response = await ApiService.postJson(
        _apiBaseUrl,
        endpoint,
        body: body,
        sessionCookie: _sessionCookie,
        csrfToken: _csrfToken,
      );
      if (response.sessionCookie != null &&
          response.sessionCookie!.isNotEmpty) {
        _sessionCookie = response.sessionCookie;
        await _persistAuthState();
      }
      return response;
    } on ApiException catch (error) {
      if (error.statusCode == 403 &&
          allowRetry &&
          error.message.contains('CSRF')) {
        await refreshSession();
        return _postJsonWithAuth(
          endpoint,
          body: body,
          allowRetry: false,
        );
      }
      await _handleAuthError(error);
      rethrow;
    }
  }

  Future<void> _handleAuthError(ApiException error) async {
    if (error.statusCode == 401) {
      await _clearAuthState(preserveSetupFlags: true);
      notifyListeners();
    }
  }

  Future<void> _persistAuthState() async {
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      await _prefs.setString(_sessionCookieKey, _sessionCookie!);
    } else {
      await _prefs.remove(_sessionCookieKey);
    }

    if (_csrfToken != null && _csrfToken!.isNotEmpty) {
      await _prefs.setString(_csrfTokenKey, _csrfToken!);
    } else {
      await _prefs.remove(_csrfTokenKey);
    }

    if (_loginId != null && _loginId!.isNotEmpty) {
      await _prefs.setString(_loginIdKey, _loginId!);
    } else {
      await _prefs.remove(_loginIdKey);
    }

    if (_role != null && _role!.isNotEmpty) {
      await _prefs.setString(_roleKey, _role!);
    } else {
      await _prefs.remove(_roleKey);
    }
  }

  Future<void> _persistSetupState() async {
    await _prefs.setBool(_setupRequiredKey, _setupRequired);
    await _prefs.setBool(_bootstrapConfiguredKey, _bootstrapConfigured);
  }

  Future<void> _clearAuthState({bool preserveSetupFlags = false}) async {
    _authenticated = false;
    _offlineMode = false;
    _sessionCookie = null;
    _csrfToken = null;
    _loginId = null;
    _role = null;
    _lastSessionSyncAt = null;

    await _prefs.remove(_sessionCookieKey);
    await _prefs.remove(_csrfTokenKey);
    await _prefs.remove(_loginIdKey);
    await _prefs.remove(_roleKey);

    if (!preserveSetupFlags) {
      _setupRequired = false;
      _bootstrapConfigured = false;
      await _prefs.remove(_setupRequiredKey);
      await _prefs.remove(_bootstrapConfiguredKey);
    }
  }

  void _refreshCacheCount() {
    _cacheEntryCount = _cacheStore.countAll();
  }

  bool get _hasPersistedSession {
    return _sessionCookie != null &&
        _sessionCookie!.isNotEmpty &&
        _loginId != null &&
        _loginId!.isNotEmpty;
  }

  String get _cacheScope {
    final userScope =
        _loginId?.trim().isNotEmpty == true ? _loginId!.trim() : 'guest';
    return '$userScope@$_apiBaseUrl';
  }
}
