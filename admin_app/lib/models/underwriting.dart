class UnderwritingCase {
  final String id;
  final String tenantId;
  final String quoteId;
  final String status;
  final int currentApprovalLevel;
  final bool requiresSeniorReview;

  UnderwritingCase({
    required this.id,
    required this.tenantId,
    required this.quoteId,
    required this.status,
    required this.currentApprovalLevel,
    required this.requiresSeniorReview,
  });

  factory UnderwritingCase.fromJson(Map<String, dynamic> json) {
    return UnderwritingCase(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      quoteId: json['quoteId'] as String,
      status: json['status'] as String,
      currentApprovalLevel: json['currentApprovalLevel'] as int,
      requiresSeniorReview: json['requiresSeniorReview'] as bool,
    );
  }
}
