import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/api.dart';

class AppState extends ChangeNotifier {
  AppState() : _apiBaseUrl = ApiService.defaultBaseUrl();

  static const String _apiBaseUrlKey = 'api_base_url';

  String _apiBaseUrl;

  String get apiBaseUrl => _apiBaseUrl;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final savedValue = prefs.getString(_apiBaseUrlKey);
    if (savedValue == null || savedValue.trim().isEmpty) {
      _apiBaseUrl = ApiService.defaultBaseUrl();
      return;
    }

    _apiBaseUrl = ApiService.normalizeBaseUrl(savedValue);
  }

  Future<void> updateApiBaseUrl(String value) async {
    _apiBaseUrl = ApiService.normalizeBaseUrl(value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_apiBaseUrlKey, _apiBaseUrl);
    notifyListeners();
  }

  Future<void> resetApiBaseUrl() async {
    _apiBaseUrl = ApiService.defaultBaseUrl();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_apiBaseUrlKey);
    notifyListeners();
  }
}
