import 'dart:convert';

import 'app_role.dart';
import 'auth_model.dart';

/// Decode JWT payload (no signature verification; backend validates).
/// Expects payload to contain: sub (id), email, roles (list of strings).
Map<String, dynamic>? decodeJwtPayload(String token) {
  try {
    final parts = token.split('.');
    if (parts.length != 3) return null;
    String payloadB64 = parts[1];
    // JWT base64url often omits padding; Dart's decoder may need it.
    final remainder = payloadB64.length % 4;
    if (remainder == 2) payloadB64 += '==';
    if (remainder == 3) payloadB64 += '=';
    final decoded = utf8.decode(base64Url.decode(payloadB64));
    return jsonDecode(decoded) as Map<String, dynamic>?;
  } catch (_) {
    return null;
  }
}

/// Build [AuthUser] from JWT payload. Expects:
/// - sub or id -> user id
/// - email -> email
/// - roles (List<String>) or role (String) -> roles
AuthUser? userFromJwtPayload(Map<String, dynamic> payload) {
  try {
    final sub = payload['sub'] ?? payload['id'];
    final id = sub == null ? '' : sub.toString();
    final email = (payload['email'] ?? '') as String;
    final tenantId =
        (payload['tenantId'] ?? payload['tenant_id'] ?? '') as String;
    List<AppRole> roles = [];
    if (payload['roles'] != null) {
      roles = appRolesFromStrings((payload['roles'] as List).cast());
    } else if (payload['role'] != null) {
      final r = appRoleFromString(payload['role'] as String);
      if (r != null) roles = [r];
    }
    if (id.isEmpty) return null;
    return AuthUser(
      id: id,
      email: email,
      roles: roles.isEmpty ? [AppRole.customer] : roles,
      tenantId: tenantId.isEmpty
          ? '00000000-0000-0000-0000-000000000001'
          : tenantId,
      displayName: payload['name'] as String?,
    );
  } catch (_) {
    return null;
  }
}
