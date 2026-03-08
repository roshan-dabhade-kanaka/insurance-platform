class PolicyCoverage {
  final String id;
  final String coverageOptionId;
  final String name;
  final String code;

  PolicyCoverage({
    required this.id,
    required this.coverageOptionId,
    required this.name,
    required this.code,
  });

  factory PolicyCoverage.fromJson(Map<String, dynamic> json) {
    final option = json['coverageOption'];
    return PolicyCoverage(
      id: json['id']?.toString() ?? '',
      coverageOptionId: json['coverageOptionId']?.toString() ?? '',
      name: option != null
          ? (option['name']?.toString() ?? 'Coverage')
          : 'Coverage',
      code: option != null ? (option['code']?.toString() ?? 'COV') : 'COV',
    );
  }
}

class Policy {
  final String id;
  final String tenantId;
  final String policyNumber;
  final String status;
  final double totalPremium;
  final DateTime inceptionDate;
  final DateTime expiryDate;
  final List<PolicyCoverage> coverages;

  Policy({
    required this.id,
    required this.tenantId,
    required this.policyNumber,
    required this.status,
    required this.totalPremium,
    required this.inceptionDate,
    required this.expiryDate,
    this.coverages = const [],
  });

  factory Policy.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? coveragesJson = json['coverages'];
    final coverages = coveragesJson != null
        ? coveragesJson.map((c) => PolicyCoverage.fromJson(c)).toList()
        : <PolicyCoverage>[];

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
      coverages: coverages,
    );
  }
}
