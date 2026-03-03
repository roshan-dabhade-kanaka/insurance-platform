class Claim {
  final String id;
  final String claimNumber;
  final String tenantId;
  final String policyId;
  final String policyCoverageId;
  final double claimedAmount;
  final String status;
  final DateTime lossDate;
  final String lossDescription;
  final Map<String, dynamic> claimantSnapshot;
  final int reopenCount;
  final String? temporalWorkflowId;
  final DateTime createdAt;

  Claim({
    required this.id,
    required this.claimNumber,
    required this.tenantId,
    required this.policyId,
    required this.policyCoverageId,
    required this.claimedAmount,
    required this.status,
    required this.lossDate,
    required this.lossDescription,
    required this.claimantSnapshot,
    required this.reopenCount,
    this.temporalWorkflowId,
    required this.createdAt,
  });

  factory Claim.fromJson(Map<String, dynamic> json) {
    return Claim(
      id: json['id'] as String,
      claimNumber: json['claimNumber'] as String? ?? 'N/A',
      tenantId: json['tenantId'] as String,
      policyId: json['policyId'] as String,
      policyCoverageId: json['policyCoverageId'] as String,
      claimedAmount: (json['claimedAmount'] as num).toDouble(),
      status: json['status'] as String,
      lossDate: DateTime.parse(json['lossDate'] as String),
      lossDescription: json['lossDescription'] as String,
      claimantSnapshot: json['claimantSnapshot'] as Map<String, dynamic>? ?? {},
      reopenCount: json['reopenCount'] as int? ?? 0,
      temporalWorkflowId: json['temporalWorkflowId'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
