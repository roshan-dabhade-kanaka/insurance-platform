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
      id: json['id']?.toString() ?? '',
      tenantId: json['tenantId']?.toString() ?? '',
      policyNumber: json['policyNumber']?.toString() ?? 'N/A',
      status: json['status']?.toString() ?? 'UNKNOWN',
      totalPremium:
          double.tryParse(
            (json['totalPremium'] ?? json['annualPremium'] ?? '0').toString(),
          ) ??
          0.0,
      inceptionDate: json['inceptionDate'] != null
          ? DateTime.parse(json['inceptionDate'].toString())
          : DateTime.now(),
      expiryDate: json['expiryDate'] != null
          ? DateTime.parse(json['expiryDate'].toString())
          : DateTime.now().add(const Duration(days: 365)),
    );
  }
}
