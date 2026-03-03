import 'app_role.dart';
import 'auth_model.dart';
import '../navigation/app_router.dart';

/// Which roles can access a route. Empty list = all authenticated.
const Map<String, List<AppRole>> routeRoles = {
  AppRouter.dashboard: [],
  AppRouter.productConfig: [AppRole.admin],
  AppRouter.coverageSetup: [AppRole.admin],
  AppRouter.ruleConfig: [AppRole.admin],
  AppRouter.riskProfiling: [
    AppRole.underwriter,
    AppRole.seniorUnderwriter,
    AppRole.admin,
  ],
  AppRouter.premiumCalculation: [
    AppRole.underwriter,
    AppRole.seniorUnderwriter,
    AppRole.admin,
  ],
  AppRouter.quoteCreation: [AppRole.agent, AppRole.admin],
  AppRouter.quoteLifecycle: [
    AppRole.agent,
    AppRole.underwriter,
    AppRole.seniorUnderwriter,
    AppRole.admin,
  ],
  AppRouter.underwritingDecision: [
    AppRole.underwriter,
    AppRole.seniorUnderwriter,
    AppRole.admin,
  ],
  AppRouter.policyIssuance: [AppRole.agent, AppRole.admin],
  AppRouter.claimSubmission: [AppRole.customer, AppRole.agent, AppRole.admin],
  AppRouter.claimInvestigation: [
    AppRole.claimsOfficer,
    AppRole.fraudAnalyst,
    AppRole.admin,
  ],
  AppRouter.fraudReview: [AppRole.fraudAnalyst, AppRole.admin],
  AppRouter.assessment: [AppRole.claimsOfficer, AppRole.admin],
  AppRouter.financePayout: [AppRole.financeOfficer, AppRole.admin],
  AppRouter.complianceAudit: [AppRole.complianceOfficer, AppRole.admin],
  AppRouter.userManagement: [AppRole.admin],
  AppRouter.tenantManagement: [AppRole.admin],
  AppRouter.reportGeneration: [AppRole.admin],
  AppRouter.productBuilder: [AppRole.admin],
  AppRouter.pricingRuleEngine: [AppRole.admin],
  AppRouter.workflowConfigurator: [AppRole.admin],
  AppRouter.lifecycleStateEditor: [AppRole.admin],
  AppRouter.slaMonitoring: [AppRole.admin],
  AppRouter.documentTemplateManager: [AppRole.admin],
  AppRouter.notificationConfiguration: [AppRole.admin],
};

/// True if user can access this route. Empty allowed = any authenticated user.
bool canAccessRoute(String path, AuthUser user) {
  final allowed = routeRoles[path] ?? routeRoles['/'];
  if (allowed == null || allowed.isEmpty) return true;
  return user.hasAnyRole(allowed);
}

/// Which roles can see a sidebar destination. Empty = all.
List<AppRole> allowedRolesForRoute(String route) {
  return routeRoles[route] ?? [];
}

/// Action keys for role checks in UI.
enum AppAction {
  underwritingApprove,
  financePayoutApproval,
  productBuilder,
  complianceAuditLogs,
}

bool canPerform(AppAction action, AuthUser user) {
  return switch (action) {
    AppAction.underwritingApprove => user.hasAnyRole([
      AppRole.underwriter,
      AppRole.seniorUnderwriter,
      AppRole.admin,
    ]),
    AppAction.financePayoutApproval => user.hasAnyRole([
      AppRole.financeOfficer,
      AppRole.admin,
    ]),
    AppAction.productBuilder => user.hasRole(AppRole.admin),
    AppAction.complianceAuditLogs => user.hasAnyRole([
      AppRole.complianceOfficer,
      AppRole.admin,
    ]),
  };
}
