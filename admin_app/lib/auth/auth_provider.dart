import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants.dart';
import 'auth_model.dart';
import 'jwt_utils.dart';

// In-memory token cache so session survives even if SharedPreferences
// throws MissingPluginException (can happen in Flutter Web dev mode).
String? _cachedToken;

Future<void> _persistToken(String? token) async {
  _cachedToken = token;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (token != null) {
      await prefs.setString('auth_token', token);
    } else {
      await prefs.remove('auth_token');
    }
  } catch (e) {
    debugPrint('SharedPreferences unavailable, using in-memory only: $e');
  }
}

Future<String?> _readToken() async {
  if (_cachedToken != null) return _cachedToken;
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  } catch (e) {
    debugPrint('SharedPreferences unavailable: $e');
    return null;
  }
}

/// Auth state holder that notifies listeners (for GoRouter refreshListenable).
class AuthNotifier extends ChangeNotifier {
  AuthNotifier({Dio? dio}) : _dio = dio;

  Dio? _dio;
  AuthState _state = AuthUnauthenticated();

  AuthState get state => _state;
  bool get isAuthenticated => _state is AuthAuthenticated;
  AuthUser? get user =>
      _state is AuthAuthenticated ? (_state as AuthAuthenticated).user : null;
  String? get token =>
      _state is AuthAuthenticated ? (_state as AuthAuthenticated).token : null;

  void setDio(Dio dio) => _dio = dio;

  Dio get _client => _dio ?? Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  Future<void> login(String email, String password) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        'auth/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data;
      if (data == null) throw Exception('No response body');
      final token =
          (data['accessToken'] ?? data['access_token'] ?? data['token'])
              as String?;
      if (token == null || token.isEmpty)
        throw Exception('No token in response');

      await _persistToken(token);
      _applyToken(token);
      notifyListeners();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message'] ?? e.response?.data?.toString()
          : e.message;
      throw Exception(msg ?? 'Login failed');
    }
  }

  void setToken(String token) {
    _applyToken(token);
    notifyListeners();
  }

  void _applyToken(String token) {
    final payload = decodeJwtPayload(token);
    if (payload == null) {
      throw Exception('Invalid token format (could not decode JWT)');
    }
    final authUser = userFromJwtPayload(payload);
    if (authUser == null) {
      throw Exception('Invalid token: missing or invalid user/roles in token');
    }
    _state = AuthAuthenticated(user: authUser, token: token);
  }

  Future<void> logout() async {
    await _persistToken(null);
    _state = AuthUnauthenticated();
    notifyListeners();
  }

  Future<void> restoreSession() async {
    try {
      final token = await _readToken();
      if (token != null && token.isNotEmpty) {
        _applyToken(token);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Session restore failed: $e');
    }
  }
}

/// Provider for [AuthNotifier].
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});

/// Bump this when login/logout so role-based widgets rebuild correctly.
final authVersionProvider = StateProvider<int>((ref) => 0);
