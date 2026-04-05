import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';
import '../services/cache_store.dart';

class CachedDataResult<T> {
  final T data;
  final bool fromCache;
  final DateTime? cachedAt;

  const CachedDataResult({
    required this.data,
    required this.fromCache,
    required this.cachedAt,
  });
}

enum UserRole {
  viewer,
  operator,
  admin,
}

extension UserRoleAccess on UserRole {
  static UserRole fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'operator':
        return UserRole.operator;
      default:
        return UserRole.viewer;
    }
  }

  int get rank {
    switch (this) {
      case UserRole.viewer:
        return 0;
      case UserRole.operator:
        return 1;
      case UserRole.admin:
        return 2;
    }
  }

  String get label {
    switch (this) {
      case UserRole.viewer:
        return 'viewer';
      case UserRole.operator:
        return 'operator';
      case UserRole.admin:
        return 'admin';
    }
  }

  bool allows(UserRole required) => rank >= required.rank;
}

class AppState extends ChangeNotifier {
  AppState() : _apiBaseUrl = ApiService.defaultBaseUrl();

  static const String _apiBaseUrlKey = 'api_base_url';
  static const String _setupRequiredKey = 'auth_setup_required';
  static const String _bootstrapConfiguredKey = 'auth_bootstrap_configured';
  static const String _sessionCookieKey = 'session_cookie';

  static const _secureStorage = FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

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
  UserRole get userRole => UserRoleAccess.fromString(_role);
  DateTime? get lastSessionSyncAt => _lastSessionSyncAt;
  int get cacheEntryCount => _cacheEntryCount;
  bool get hasOperatorAccess => canAccess(UserRole.operator);
  bool get hasAdminAccess => canAccess(UserRole.admin);

  bool canAccess(UserRole requiredRole) {
    if (!_authenticated) {
      return false;
    }
    return userRole.allows(requiredRole);
  }

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _cacheStore = ApiCacheStore(_prefs);

    final savedBaseUrl = _prefs.getString(_apiBaseUrlKey);
    if (savedBaseUrl != null && savedBaseUrl.trim().isNotEmpty) {
      _apiBaseUrl = ApiService.normalizeBaseUrl(savedBaseUrl);
    }

    _setupRequired = _prefs.getBool(_setupRequiredKey) ?? false;
    _bootstrapConfigured = _prefs.getBool(_bootstrapConfiguredKey) ?? false;
    _refreshCacheCount();

    // Restore persisted session cookie so the user doesn't need to log in again.
    final savedCookie = await _secureStorage.read(key: _sessionCookieKey);
    if (savedCookie != null && savedCookie.isNotEmpty) {
      _sessionCookie = savedCookie;
    }

    try {
      await refreshSession(notify: false);
    } catch (_) {
      // Keep setup hints and require a fresh login if the backend is unavailable.
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
        await _secureStorage.write(
          key: _sessionCookieKey,
          value: _sessionCookie,
        );
      }

      final user = payload['user'];
      if (payload['authenticated'] == true && user is Map) {
        _authenticated = true;
        _offlineMode = false;
        _loginId = user['login_id']?.toString();
        _role = user['role']?.toString();
        _csrfToken = payload['csrf_token']?.toString();
      } else {
        await _clearAuthState(preserveSetupFlags: true);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401) {
        await _clearAuthState(preserveSetupFlags: true);
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
    await _secureStorage.write(key: _sessionCookieKey, value: _sessionCookie);
    _csrfToken = response.data['csrf_token']?.toString();
    _loginId = user['login_id']?.toString();
    _role = user['role']?.toString();
    _setupRequired = false;
    _lastSessionSyncAt = DateTime.now();
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

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final trimmedCurrent = currentPassword.trim();
    final trimmedNext = newPassword.trim();
    if (trimmedCurrent.isEmpty || trimmedNext.isEmpty) {
      throw const ApiException('현재 비밀번호와 새 비밀번호를 모두 입력하세요.');
    }
    if (trimmedNext.length < 12) {
      throw const ApiException('새 비밀번호는 최소 12자 이상이어야 합니다.');
    }

    final scope = _cacheScope;
    await _postJsonWithAuth(
      '/api/auth/change-password',
      body: {
        'current_password': trimmedCurrent,
        'new_password': trimmedNext,
      },
    );
    await _clearAuthState();
    await _cacheStore.clearScope(scope);
    _refreshCacheCount();
    notifyListeners();
  }

  Future<CachedDataResult<T>> fetchMapParsed<T>(
    String endpoint, {
    Map<String, Object?>? params,
    required T Function(Map<String, dynamic> json) parser,
    Duration cacheTtl = const Duration(minutes: 30),
    bool allowStaleOnError = true,
  }) async {
    final cacheEntry = _cacheStore.read(
      scope: _cacheScope,
      baseUrl: _apiBaseUrl,
      endpoint: endpoint,
      params: params,
    );
    final canUseCache = _isCacheFresh(cacheEntry, cacheTtl);
    final wasOffline = _offlineMode;

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
      }
      await _cacheStore.write(
        scope: _cacheScope,
        baseUrl: _apiBaseUrl,
        endpoint: endpoint,
        params: params,
        data: response.data,
      );
      _refreshCacheCount();
      return CachedDataResult<T>(
        data: parser(response.data),
        fromCache: false,
        cachedAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      await _handleAuthError(error);
      if (allowStaleOnError &&
          canUseCache &&
          cacheEntry != null &&
          cacheEntry.data is Map) {
        final changed = !_offlineMode;
        _offlineMode = true;
        if (changed) {
          notifyListeners();
        }
        return CachedDataResult<T>(
          data: parser(Map<String, dynamic>.from(cacheEntry.data as Map)),
          fromCache: true,
          cachedAt: cacheEntry.cachedAt,
        );
      }
      rethrow;
    } finally {
      if (!_offlineMode && wasOffline) {
        notifyListeners();
      }
    }
  }

  Future<CachedDataResult<T>> fetchListParsed<T>(
    String endpoint, {
    Map<String, Object?>? params,
    required T Function(List<dynamic> json) parser,
    Duration cacheTtl = const Duration(minutes: 30),
    bool allowStaleOnError = true,
  }) async {
    final cacheEntry = _cacheStore.read(
      scope: _cacheScope,
      baseUrl: _apiBaseUrl,
      endpoint: endpoint,
      params: params,
    );
    final canUseCache = _isCacheFresh(cacheEntry, cacheTtl);
    final wasOffline = _offlineMode;

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
      }
      await _cacheStore.write(
        scope: _cacheScope,
        baseUrl: _apiBaseUrl,
        endpoint: endpoint,
        params: params,
        data: response.data,
      );
      _refreshCacheCount();
      return CachedDataResult<T>(
        data: parser(response.data),
        fromCache: false,
        cachedAt: DateTime.now(),
      );
    } on ApiException catch (error) {
      await _handleAuthError(error);
      if (allowStaleOnError &&
          canUseCache &&
          cacheEntry != null &&
          cacheEntry.data is List) {
        final changed = !_offlineMode;
        _offlineMode = true;
        if (changed) {
          notifyListeners();
        }
        return CachedDataResult<T>(
          data: parser(List<dynamic>.from(cacheEntry.data as List)),
          fromCache: true,
          cachedAt: cacheEntry.cachedAt,
        );
      }
      rethrow;
    } finally {
      if (!_offlineMode && wasOffline) {
        notifyListeners();
      }
    }
  }

  Future<Map<String, dynamic>> postJson(
    String endpoint, {
    Map<String, dynamic>? body,
    String method = 'POST',
  }) async {
    final response = await _postJsonWithAuth(endpoint, body: body, method: method);
    final changed = _offlineMode;
    _offlineMode = false;
    if (changed) {
      notifyListeners();
    }
    return response.data;
  }

  Future<ApiResponse<Map<String, dynamic>>> _postJsonWithAuth(
    String endpoint, {
    Map<String, dynamic>? body,
    bool allowRetry = true,
    String method = 'POST',
  }) async {
    try {
      final response = await ApiService.postJson(
        _apiBaseUrl,
        endpoint,
        body: body,
        sessionCookie: _sessionCookie,
        csrfToken: _csrfToken,
        method: method,
      );
      if (response.sessionCookie != null &&
          response.sessionCookie!.isNotEmpty) {
        _sessionCookie = response.sessionCookie;
        await _secureStorage.write(
          key: _sessionCookieKey,
          value: _sessionCookie,
        );
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
          method: method,
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
    await _secureStorage.delete(key: _sessionCookieKey);

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

  bool _isCacheFresh(CacheEntry? entry, Duration ttl) {
    if (entry == null) {
      return false;
    }
    return DateTime.now().difference(entry.cachedAt) <= ttl;
  }

  String get _cacheScope {
    final userScope =
        _loginId?.trim().isNotEmpty == true ? _loginId!.trim() : 'guest';
    return '$userScope@$_apiBaseUrl';
  }
}
