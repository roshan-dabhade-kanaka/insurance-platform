/// Single audit log record from backend (Quote, Claim, Underwriting, Payout, Workflow).
class AuditLog {
  final String id;
  final String tenantId;
  final String entityType;
  final String entityId;
  final String action;
  final String? oldState;
  final String? newState;
  final String? changedBy;
  final Map<String, dynamic> changeContext;
  final DateTime occurredAt;

  AuditLog({
    required this.id,
    required this.tenantId,
    required this.entityType,
    required this.entityId,
    required this.action,
    this.oldState,
    this.newState,
    this.changedBy,
    Map<String, dynamic>? changeContext,
    required this.occurredAt,
  }) : changeContext = changeContext ?? const {};

  factory AuditLog.fromJson(Map<String, dynamic> json) {
    return AuditLog(
      id: json['id'].toString(),
      tenantId: (json['tenantId'] ?? '').toString(),
      entityType: (json['entityType'] ?? '').toString(),
      entityId: (json['entityId'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      oldState: json['oldState'] as String?,
      newState: json['newState'] as String?,
      changedBy: json['changedBy'] as String?,
      changeContext: json['changeContext'] is Map<String, dynamic>
          ? json['changeContext'] as Map<String, dynamic>
          : const {},
      occurredAt: DateTime.tryParse(json['occurredAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Paginated response from GET /audit/logs.
class AuditLogPage {
  const AuditLogPage({
    required this.content,
    required this.totalElements,
    required this.totalPages,
    required this.number,
    required this.size,
  });

  final List<AuditLog> content;
  final int totalElements;
  final int totalPages;
  final int number;
  final int size;

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    final content = (json['content'] as List<dynamic>?)
            ?.map((e) => AuditLog.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return AuditLogPage(
      content: content,
      totalElements: json['totalElements'] as int? ?? content.length,
      totalPages: json['totalPages'] as int? ?? 1,
      number: json['number'] as int? ?? 0,
      size: json['size'] as int? ?? content.length,
    );
  }
}

/// Entity type filter for audit (maps to backend entityType).
enum AuditEntityFilter {
  all('All', null),
  quote('Quote History', 'QUOTE'),
  claim('Claim History', 'CLAIM'),
  underwriting('Underwriting Decisions', 'UW_CASE'),
  payout('Payout Authorization', 'PAYOUT'),
  workflow('Workflow State Changes', 'WORKFLOW');

  const AuditEntityFilter(this.label, this.entityType);
  final String label;
  final String? entityType;
}
