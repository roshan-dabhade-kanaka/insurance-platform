import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import 'auth_model.dart';
import 'jwt_utils.dart';

/// Auth state holder that notifies listeners (for GoRouter refreshListenable).
/// Login calls backend, stores JWT, decodes roles. Logout clears state.
class AuthNotifier extends ChangeNotifier {
  AuthNotifier({Dio? dio}) : _dio = dio;

  Dio? _dio;
  AuthState _state = AuthUnauthenticated();

  AuthState get state => _state;
  bool get isAuthenticated => _state is AuthAuthenticated;
  AuthUser? get user => _state is AuthAuthenticated ? (_state as AuthAuthenticated).user : null;
  String? get token => _state is AuthAuthenticated ? (_state as AuthAuthenticated).token : null;

  void setDio(Dio dio) {
    _dio = dio;
  }

  Dio get _client => _dio ?? Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  /// Login with email/password; backend returns { "accessToken": "jwt..." } or similar.
  Future<void> login(String email, String password) async {
    try {
      final response = await _client.post<Map<String, dynamic>>(
        '/auth/login',
        data: {'email': email, 'password': password},
      );
      final data = response.data;
      if (data == null) throw Exception('No response body');
      final token = (data['accessToken'] ?? data['access_token'] ?? data['token']) as String?;
      if (token == null || token.isEmpty) throw Exception('No token in response');
      _applyToken(token);
      notifyListeners();
    } on DioException catch (e) {
      final msg = e.response?.data is Map
          ? (e.response!.data as Map)['message'] ?? e.response?.data?.toString()
          : e.message;
      throw Exception(msg ?? 'Login failed');
    }
  }

  /// Set auth from JWT (e.g. after restore from storage). No network.
  void setToken(String token) {
    _applyToken(token);
    notifyListeners();
  }

  void _applyToken(String token) {
    final payload = decodeJwtPayload(token);
    if (payload == null) throw Exception('Invalid token format (could not decode JWT)');
    final authUser = userFromJwtPayload(payload);
    if (authUser == null) throw Exception('Invalid token: missing or invalid user/roles in token');
    _state = AuthAuthenticated(user: authUser, token: token);
  }

  void logout() {
    _state = AuthUnauthenticated();
    notifyListeners();
  }
}

/// Provider for [AuthNotifier]. Override in main with shared instance for GoRouter.
final authNotifierProvider = ChangeNotifierProvider<AuthNotifier>((ref) {
  return AuthNotifier();
});

/// Bump this when login/logout so widgets that depend on current user (e.g. sidebar)
/// rebuild and show the correct role-based tabs. ChangeNotifier.notifyListeners()
/// does not trigger Riverpod to re-evaluate, so we need this.
final authVersionProvider = StateProvider<int>((ref) => 0);
