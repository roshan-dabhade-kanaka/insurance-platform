class Claim {
  final String id;
  final String claimNumber;
  final String tenantId;
  final String policyId;
  final String policyCoverageId;
  final double claimedAmount;
  final double? approvedAmount;
  final double paidAmount;
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
    this.approvedAmount,
    required this.paidAmount,
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
      id: json['id']?.toString() ?? '',
      claimNumber: json['claimNumber']?.toString() ?? 'N/A',
      tenantId: json['tenantId']?.toString() ?? '',
      policyId: json['policyId']?.toString() ?? '',
      policyCoverageId: json['policyCoverageId']?.toString() ?? '',
      claimedAmount:
          double.tryParse(json['claimedAmount']?.toString() ?? '0') ?? 0.0,
      approvedAmount: json['approvedAmount'] != null
          ? double.tryParse(json['approvedAmount'].toString())
          : null,
      paidAmount: double.tryParse(json['paidAmount']?.toString() ?? '0') ?? 0.0,
      status: json['status']?.toString() ?? 'UNKNOWN',
      lossDate: json['lossDate'] != null
          ? DateTime.parse(json['lossDate'].toString())
          : DateTime.now(),
      lossDescription: json['lossDescription']?.toString() ?? '',
      claimantSnapshot:
          json['claimantData'] as Map<String, dynamic>? ??
          json['claimantSnapshot'] as Map<String, dynamic>? ??
          {},
      reopenCount: json['reopenCount'] is int
          ? json['reopenCount']
          : int.tryParse(json['reopenCount']?.toString() ?? '0') ?? 0,
      temporalWorkflowId: json['temporalWorkflowId']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }
}
