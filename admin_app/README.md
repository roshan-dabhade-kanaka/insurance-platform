# InsureAdmin – Flutter Web Admin Panel

Insurance Policy Configuration and Underwriting Platform admin UI, converted from the `ui-html` HTML screens to a Flutter Web app.

## Requirements

- **Flutter SDK** (stable, with web support)
- **Material 3** design, **modular architecture**, **responsive** layout

## Structure

```
lib/
├── main.dart                 # App entry, MaterialApp.router, theme
├── theme/
│   └── app_theme.dart        # Material 3 light/dark, primary #135BEC, Manrope
├── layout/
│   ├── app_layout.dart       # Sidebar + header + main content (responsive)
│   ├── sidebar_navigation.dart
│   └── top_header.dart
├── navigation/
│   └── app_router.dart       # go_router routes + sidebar destinations
├── widgets/                  # Reusable widgets
│   ├── dynamic_form_widget.dart
│   ├── workflow_stepper_widget.dart
│   ├── approval_decision_panel.dart
│   ├── rule_builder_widget.dart
│   ├── json_preview_panel.dart
│   ├── audit_log_table.dart
│   ├── paginated_data_table_widget.dart
│   ├── lifecycle_editor_widget.dart
│   ├── document_template_mapper.dart
│   ├── notification_config_widget.dart
│   └── widgets.dart
└── pages/                    # One page per admin screen
    ├── dashboard_page.dart
    ├── product_configuration_page.dart
    ├── coverage_setup_page.dart
    ├── rule_configuration_page.dart
    ├── risk_profiling_page.dart
    ├── premium_calculation_page.dart
    ├── quote_lifecycle_page.dart
    ├── underwriting_decision_page.dart
    ├── policy_issuance_page.dart
    ├── claim_submission_page.dart
    ├── claim_investigation_page.dart
    ├── fraud_review_page.dart
    ├── assessment_page.dart
    ├── finance_payout_approval_page.dart
    ├── compliance_audit_logs_page.dart
    ├── user_management_page.dart
    ├── tenant_management_page.dart
    ├── report_generation_page.dart
    ├── product_builder_page.dart
    ├── pricing_rule_engine_page.dart
    ├── workflow_configurator_page.dart
    ├── lifecycle_state_editor_page.dart
    ├── sla_monitoring_page.dart
    ├── document_template_manager_page.dart
    ├── notification_configuration_page.dart
    └── pages.dart
```

## Run (Web)

```bash
cd admin_app
flutter pub get
flutter run -d chrome
```

## Build (Web)

```bash
flutter build web
```

Output: `build/web/`

## Conversions

- **HTML forms** → `DynamicFormWidget` (text, number, date, dropdown, checkbox, radio)
- **Workflow UI** → `WorkflowStepperWidget` + `LifecycleEditorWidget`
- **Tables** → `PaginatedDataTableWidget` + `AuditLogTable`
- **Rule/JSON panels** → `JsonPreviewPanel` + `RuleBuilderWidget`
- **Approval panels** → `ApprovalDecisionPanel`
- **Document templates** → `DocumentTemplateMapper`
- **Notifications** → `NotificationConfigWidget`

All layout is driven by the shared **App Layout** (sidebar, top header, main content); no hardcoded layout logic in pages.
