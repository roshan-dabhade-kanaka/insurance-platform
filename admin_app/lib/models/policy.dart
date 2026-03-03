class Policy {
  final String id;
  final String tenantId;
  final String policyNumber;
  final String status;
  final double totalPremium;
  final DateTime inceptionDate;
  final DateTime expiryDate;

  Policy({
    required this.id,
    required this.tenantId,
    required this.policyNumber,
    required this.status,
    required this.totalPremium,
    required this.inceptionDate,
    required this.expiryDate,
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    return Policy(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      policyNumber: json['policyNumber'] as String,
      status: json['status'] as String,
      totalPremium: (json['totalPremium'] as num).toDouble(),
      inceptionDate: DateTime.parse(json['inceptionDate'] as String),
      expiryDate: DateTime.parse(json['expiryDate'] as String),
    );
  }
}
