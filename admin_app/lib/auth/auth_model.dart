import 'app_role.dart';

/// Logged-in user with roles from JWT.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.roles,
    required this.tenantId,
    this.displayName,
  });

  final String id;
  final String email;
  final List<AppRole> roles;
  final String tenantId;
  final String? displayName;

  bool hasRole(AppRole role) => roles.contains(role);
  bool hasAnyRole(List<AppRole> list) => list.any(hasRole);
}

/// Auth state: either signed out or signed in with user + token.
sealed class AuthState {}

class AuthUnauthenticated extends AuthState {}

class AuthAuthenticated extends AuthState {
  AuthAuthenticated({required this.user, required this.token});
  final AuthUser user;
  final String token;
}
