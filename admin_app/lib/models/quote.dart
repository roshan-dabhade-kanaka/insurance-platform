class Quote {
  final String id;
  final String tenantId;
  final String productVersionId;
  final String status;
  final Map<String, dynamic> applicantSnapshot;
  final String? temporalWorkflowId;
  final DateTime createdAt;
  final DateTime expiresAt;

  Quote({
    required this.id,
    required this.tenantId,
    required this.productVersionId,
    required this.status,
    required this.applicantSnapshot,
    this.temporalWorkflowId,
    required this.createdAt,
    required this.expiresAt,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      productVersionId: json['productVersionId'] as String,
      status: json['status'] as String,
      applicantSnapshot: json['applicantSnapshot'] as Map<String, dynamic>,
      temporalWorkflowId: json['temporalWorkflowId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'productVersionId': productVersionId,
      'status': status,
      'applicantSnapshot': applicantSnapshot,
      'temporalWorkflowId': temporalWorkflowId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
    };
  }
}
