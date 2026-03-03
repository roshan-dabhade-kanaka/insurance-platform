/// Roles for RBAC. Backend JWT should send these (e.g. "roles": ["underwriter","admin"]).
enum AppRole {
  admin,
  agent,
  underwriter,
  seniorUnderwriter,
  claimsOfficer,
  fraudAnalyst,
  financeOfficer,
  complianceOfficer,
  customer,
}

extension AppRoleX on AppRole {
  String get value => name;
}

/// Parse role from string (e.g. from JWT). Case-insensitive so backend
/// "Admin"/"ClaimsOfficer" and demo "admin"/"claimsOfficer" both work.
AppRole? appRoleFromString(String s) {
  if (s.isEmpty) return null;
  final lower = s.toLowerCase();
  return AppRole.values.cast<AppRole?>().firstWhere(
    (r) => r!.name.toLowerCase() == lower,
    orElse: () => null,
  );
}

List<AppRole> appRolesFromStrings(List<dynamic> list) {
  return list
      .map((e) => e is String ? appRoleFromString(e) : null)
      .whereType<AppRole>()
      .toList();
}
