class PayoutRequest {
  final String id;
  final String claimId;
  final String assessmentId;
  final String status;
  final double totalAmount;
  final String currencyCode;
  final String requestedBy;
  final double? approvedAmount;
  final DateTime createdAt;

  PayoutRequest({
    required this.id,
    required this.claimId,
    required this.assessmentId,
    required this.status,
    required this.totalAmount,
    required this.currencyCode,
    required this.requestedBy,
    this.approvedAmount,
    required this.createdAt,
  });

  factory PayoutRequest.fromJson(Map<String, dynamic> json) {
    return PayoutRequest(
      id: json['id'] as String,
      claimId: json['claimId'] as String,
      assessmentId: json['assessmentId'] as String,
      status: json['status'] as String,
      totalAmount: double.parse(json['totalAmount'] as String),
      currencyCode: json['currencyCode'] as String,
      requestedBy: json['requestedBy'] as String,
      approvedAmount: json['approvedAmount'] != null
          ? double.parse(json['approvedAmount'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
