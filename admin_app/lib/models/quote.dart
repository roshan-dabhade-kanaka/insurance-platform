class Quote {
  final String id;
  final String tenantId;
  final String quoteNumber;
  final String productVersionId;
  final String status;
  final String? applicantRef;
  final Map<String, dynamic> applicantSnapshot;
  final String? temporalWorkflowId;
  final DateTime createdAt;
  final DateTime expiresAt;

  final bool hasPremium;
  final List<QuoteLineItem> lineItems;

  Quote({
    required this.id,
    required this.tenantId,
    required this.quoteNumber,
    required this.productVersionId,
    required this.status,
    this.applicantRef,
    required this.applicantSnapshot,
    this.temporalWorkflowId,
    required this.createdAt,
    required this.expiresAt,
    this.hasPremium = false,
    this.lineItems = const [],
  });

  Quote copyWith({
    String? id,
    String? tenantId,
    String? quoteNumber,
    String? productVersionId,
    String? status,
    String? applicantRef,
    Map<String, dynamic>? applicantSnapshot,
    String? temporalWorkflowId,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? hasPremium,
    List<QuoteLineItem>? lineItems,
  }) {
    return Quote(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      productVersionId: productVersionId ?? this.productVersionId,
      status: status ?? this.status,
      applicantRef: applicantRef ?? this.applicantRef,
      applicantSnapshot: applicantSnapshot ?? this.applicantSnapshot,
      temporalWorkflowId: temporalWorkflowId ?? this.temporalWorkflowId,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      hasPremium: hasPremium ?? this.hasPremium,
      lineItems: lineItems ?? this.lineItems,
    );
  }

  factory Quote.fromJson(Map<String, dynamic> json) {
    final snapshots = json['premiumSnapshots'] as List?;
    final hasPremium = snapshots != null && snapshots.isNotEmpty;

    final items = json['lineItems'] as List?;
    final lineItems = items != null
        ? items
              .map((i) => QuoteLineItem.fromJson(i as Map<String, dynamic>))
              .toList()
        : <QuoteLineItem>[];

    return Quote(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      quoteNumber: (json['quoteNumber'] ?? '').toString(),
      productVersionId: json['productVersionId'] as String,
      status: json['status'] as String,
      applicantRef: json['applicantRef']?.toString(),
      applicantSnapshot:
          (json['applicantSnapshot'] ?? json['applicantData'] ?? {})
              as Map<String, dynamic>,
      temporalWorkflowId: json['temporalWorkflowId'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : DateTime.now().add(const Duration(days: 30)),
      hasPremium: hasPremium,
      lineItems: lineItems,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenantId': tenantId,
      'quoteNumber': quoteNumber,
      'productVersionId': productVersionId,
      'status': status,
      'applicantRef': applicantRef,
      'applicantSnapshot': applicantSnapshot,
      'temporalWorkflowId': temporalWorkflowId,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'lineItems': lineItems.map((i) => i.toJson()).toList(),
    };
  }
}

class QuoteLineItem {
  final String id;
  final String coverageOptionId;
  final String? riderId;
  final double sumInsured;

  QuoteLineItem({
    required this.id,
    required this.coverageOptionId,
    this.riderId,
    required this.sumInsured,
  });

  factory QuoteLineItem.fromJson(Map<String, dynamic> json) {
    return QuoteLineItem(
      id: json['id'] as String,
      coverageOptionId: json['coverageOptionId'] as String,
      riderId: json['riderId'] as String?,
      sumInsured: double.tryParse(json['sumInsured']?.toString() ?? '0') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coverageOptionId': coverageOptionId,
      'riderId': riderId,
      'sumInsured': sumInsured,
    };
  }
}
