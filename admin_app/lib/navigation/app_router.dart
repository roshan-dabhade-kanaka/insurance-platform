import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_provider.dart';
import '../auth/role_access.dart';
import '../layout/app_layout.dart';
import '../pages/pages.dart';
import '../screens/rule_builder_screen.dart';
import '../screens/create_quote_screen.dart';

/// Route paths and sidebar config. Single source for nav destinations.
class AppRouter {
  AppRouter._();

  static const String login = '/login';
  static const String dashboard = '/';
  static const String productConfig = '/product-configuration';
  static const String coverageSetup = '/coverage-setup';
  static const String ruleConfig = '/rule-configuration';
  static const String ruleBuilder = '/rule-builder';
  static const String riskProfiling = '/risk-profiling';
  static const String premiumCalculation = '/premium-calculation';
  static const String quoteCreation = '/quote-creation';
  static const String quoteLifecycle = '/quote-lifecycle';
  static const String underwritingDecision = '/underwriting-decision';
  static const String policyIssuance = '/policy-issuance';
  static const String claimSubmission = '/claim-submission';
  static const String claimInvestigation = '/claim-investigation';
  static const String fraudReview = '/fraud-review';
  static const String assessment = '/assessment';
  static const String financePayout = '/finance-payout-approval';
  static const String complianceAudit = '/compliance-audit-logs';
  static const String userManagement = '/user-management';
  static const String tenantManagement = '/tenant-management';
  static const String reportGeneration = '/report-generation';
  static const String productBuilder = '/product-builder';
  static const String pricingRuleEngine = '/pricing-rule-engine';
  static const String workflowConfigurator = '/workflow-configurator';
  static const String lifecycleStateEditor = '/lifecycle-state-editor';
  static const String slaMonitoring = '/sla-monitoring';
  static const String documentTemplateManager = '/document-template-manager';
  static const String notificationConfiguration = '/notification-configuration';

  static final List<SidebarDestination> sidebarDestinations = [
    SidebarDestination(
      route: dashboard,
      label: 'Dashboard',
      icon: Icons.dashboard_outlined,
    ),
    SidebarDestination(
      route: productConfig,
      label: 'Product Configuration',
      icon: Icons.inventory_2_outlined,
    ),
    SidebarDestination(
      route: coverageSetup,
      label: 'Coverage Setup',
      icon: Icons.verified_user_outlined,
    ),
    SidebarDestination(
      route: ruleConfig,
      label: 'Rule Configuration',
      icon: Icons.rule_outlined,
    ),
    SidebarDestination(
      route: riskProfiling,
      label: 'Risk Profiling',
      icon: Icons.assessment_outlined,
    ),
    SidebarDestination(
      route: premiumCalculation,
      label: 'Premium Calculation',
      icon: Icons.calculate_outlined,
    ),
    SidebarDestination(
      route: quoteCreation,
      label: 'Create Quote',
      icon: Icons.add_chart_outlined,
    ),
    SidebarDestination(
      route: quoteLifecycle,
      label: 'Quote Lifecycle',
      icon: Icons.timeline_outlined,
    ),
    SidebarDestination(
      route: underwritingDecision,
      label: 'Underwriting Decision',
      icon: Icons.gavel_outlined,
    ),
    SidebarDestination(
      route: policyIssuance,
      label: 'Policy Issuance',
      icon: Icons.task_outlined,
    ),
    SidebarDestination(
      route: claimSubmission,
      label: 'Claim Submission',
      icon: Icons.upload_file_outlined,
    ),
    SidebarDestination(
      route: claimInvestigation,
      label: 'Claim Investigation',
      icon: Icons.search_outlined,
    ),
    SidebarDestination(
      route: fraudReview,
      label: 'Fraud Review',
      icon: Icons.warning_amber_outlined,
    ),
    SidebarDestination(
      route: assessment,
      label: 'Assessment',
      icon: Icons.fact_check_outlined,
    ),
    SidebarDestination(
      route: financePayout,
      label: 'Finance Payout Approval',
      icon: Icons.account_balance_wallet_outlined,
    ),
    SidebarDestination(
      route: complianceAudit,
      label: 'Compliance Audit Logs',
      icon: Icons.history_outlined,
    ),
    SidebarDestination(
      route: userManagement,
      label: 'User Management',
      icon: Icons.people_outlined,
    ),
    SidebarDestination(
      route: tenantManagement,
      label: 'Tenant Management',
      icon: Icons.business_outlined,
    ),
    SidebarDestination(
      route: reportGeneration,
      label: 'Report Generation',
      icon: Icons.summarize_outlined,
    ),
    SidebarDestination(
      route: productBuilder,
      label: 'Product Builder',
      icon: Icons.build_outlined,
    ),
    SidebarDestination(
      route: pricingRuleEngine,
      label: 'Pricing Rule Engine',
      icon: Icons.tune_outlined,
    ),
    SidebarDestination(
      route: workflowConfigurator,
      label: 'Workflow Configurator',
      icon: Icons.account_tree_outlined,
    ),
    SidebarDestination(
      route: lifecycleStateEditor,
      label: 'Lifecycle State Editor',
      icon: Icons.linear_scale_outlined,
    ),
    SidebarDestination(
      route: slaMonitoring,
      label: 'SLA Monitoring',
      icon: Icons.schedule_outlined,
    ),
    SidebarDestination(
      route: documentTemplateManager,
      label: 'Document Template Manager',
      icon: Icons.snippet_folder_outlined,
    ),
    SidebarDestination(
      route: notificationConfiguration,
      label: 'Notification Configuration',
      icon: Icons.notifications_active_outlined,
    ),
  ];

  static String _titleForPath(String path) {
    if (path == '/' || path.isEmpty) return 'Dashboard';
    if (path == login) return 'Sign in';
    for (final d in sidebarDestinations) {
      if (d.route == path) return d.label;
    }
    return 'InsureAdmin';
  }

  static GoRouter createRouter(AuthNotifier auth) {
    return GoRouter(
      initialLocation: dashboard,
      refreshListenable: auth,
      redirect: (context, state) {
        final path = state.uri.path;
        final authenticated = auth.isAuthenticated;
        final user = auth.user;

        if (!authenticated) {
          return path == login ? null : login;
        }
        if (path == login) return dashboard;
        if (user != null && !canAccessRoute(path, user)) {
          return dashboard;
        }
        return null;
      },
      routes: [
        GoRoute(
          path: login,
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: LoginPage()),
        ),
        ShellRoute(
          builder: (context, state, child) {
            final path = state.uri.path;
            return AppLayout(title: _titleForPath(path), child: child);
          },
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DashboardPage()),
            ),
            GoRoute(
              path: '/product-configuration',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProductConfigurationPage()),
            ),
            GoRoute(
              path: '/coverage-setup',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CoverageSetupPage()),
            ),
            GoRoute(
              path: '/rule-configuration',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: RuleConfigurationPage()),
            ),
            GoRoute(
              path: '/rule-builder',
              pageBuilder: (context, state) {
                final extra = state.extra as Map<String, dynamic>?;
                return NoTransitionPage(
                  child: RuleBuilderScreen(
                    versionId: extra?['versionId'],
                    initialRuleType: extra?['ruleType'],
                    existingRule: extra?['existingRule'],
                  ),
                );
              },
            ),
            GoRoute(
              path: '/risk-profiling',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: RiskProfilingPage()),
            ),
            GoRoute(
              path: '/premium-calculation',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: PremiumCalculationPage()),
            ),
            GoRoute(
              path: '/quote-creation',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: CreateQuoteScreen()),
            ),
            GoRoute(
              path: '/quote-lifecycle',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: QuoteLifecyclePage()),
            ),
            GoRoute(
              path: '/underwriting-decision',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: UnderwritingDecisionPage()),
            ),
            GoRoute(
              path: '/policy-issuance',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: PolicyIssuancePage()),
            ),
            GoRoute(
              path: '/claim-submission',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ClaimSubmissionPage()),
            ),
            GoRoute(
              path: '/claim-investigation',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ClaimInvestigationPage()),
            ),
            GoRoute(
              path: '/fraud-review',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: FraudReviewPage()),
            ),
            GoRoute(
              path: '/assessment',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: AssessmentPage()),
            ),
            GoRoute(
              path: '/finance-payout-approval',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: FinancePayoutApprovalPage()),
            ),
            GoRoute(
              path: '/compliance-audit-logs',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ComplianceAuditLogsPage()),
            ),
            GoRoute(
              path: '/user-management',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: UserManagementPage()),
            ),
            GoRoute(
              path: '/tenant-management',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: TenantManagementPage()),
            ),
            GoRoute(
              path: '/report-generation',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ReportGenerationPage()),
            ),
            GoRoute(
              path: '/product-builder',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: ProductBuilderPage()),
            ),
            GoRoute(
              path: '/pricing-rule-engine',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: PricingRuleEnginePage()),
            ),
            GoRoute(
              path: '/workflow-configurator',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: WorkflowConfiguratorPage()),
            ),
            GoRoute(
              path: '/lifecycle-state-editor',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: LifecycleStateEditorPage()),
            ),
            GoRoute(
              path: '/sla-monitoring',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: SLAMonitoringPage()),
            ),
            GoRoute(
              path: '/document-template-manager',
              pageBuilder: (context, state) =>
                  const NoTransitionPage(child: DocumentTemplateManagerPage()),
            ),
            GoRoute(
              path: '/notification-configuration',
              pageBuilder: (context, state) => const NoTransitionPage(
                child: NotificationConfigurationPage(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class SidebarDestination {
  const SidebarDestination({
    required this.route,
    required this.label,
    required this.icon,
  });
  final String route;
  final String label;
  final IconData icon;
}
