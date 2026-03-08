import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../models/quote.dart';
import '../auth/auth_provider.dart';
import '../core/constants.dart';

// ---------------------------------------------------------------------------
// Models
// ---------------------------------------------------------------------------

class AdminUser {
  final String id;
  final String email;
  final List<String> roles;
  final String? tenantId;
  final String? name;

  const AdminUser({
    required this.id,
    required this.email,
    required this.roles,
    this.tenantId,
    this.name,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final rawRoles = json['roles'];
    List<String> roles = [];
    if (rawRoles is List) {
      roles = rawRoles.map((r) {
        if (r is String) return r;
        if (r is Map) return (r['name'] ?? r['value'] ?? '').toString();
        return r.toString();
      }).toList();
    } else if (rawRoles is String) {
      roles = [rawRoles];
    }
    String? nameValue =
        json['name']?.toString() ?? json['displayName']?.toString();
    if (nameValue == null && json['first_name'] != null) {
      nameValue = '${json['first_name']} ${json['last_name'] ?? ''}'.trim();
    } else if (nameValue == null && json['firstName'] != null) {
      nameValue = '${json['firstName']} ${json['lastName'] ?? ''}'.trim();
    }
    return AdminUser(
      id: (json['id'] ?? json['sub'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      roles: roles,
      tenantId: json['tenantId']?.toString() ?? json['tenant_id']?.toString(),
      name: nameValue,
    );
  }
}

class Tenant {
  final String id;
  final String name;
  final String? plan;
  final bool isActive;

  const Tenant({
    required this.id,
    required this.name,
    this.plan,
    required this.isActive,
  });

  factory Tenant.fromJson(Map<String, dynamic> json) {
    return Tenant(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      plan: json['plan']?.toString() ?? json['subscriptionPlan']?.toString(),
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? true,
    );
  }
}

class ProcessedTodayStats {
  final double amount;
  final int count;

  const ProcessedTodayStats({required this.amount, required this.count});

  factory ProcessedTodayStats.fromJson(Map<String, dynamic> json) {
    return ProcessedTodayStats(
      amount: (json['amount'] ?? json['totalAmount'] ?? 0) is num
          ? ((json['amount'] ?? json['totalAmount']) as num).toDouble()
          : 0,
      count: (json['count'] ?? json['successfulPayouts'] ?? 0) is num
          ? ((json['count'] ?? json['successfulPayouts']) as num).toInt()
          : 0,
    );
  }
}

class CoverageOption {
  final String id;
  final String name;
  final String code;
  final bool isMandatory;
  final double? minSumInsured;
  final double? maxSumInsured;

  const CoverageOption({
    required this.id,
    required this.name,
    required this.code,
    required this.isMandatory,
    this.minSumInsured,
    this.maxSumInsured,
  });

  factory CoverageOption.fromJson(Map<String, dynamic> json) {
    return CoverageOption(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Coverage').toString(),
      code: (json['code'] ?? '').toString(),
      isMandatory: json['isMandatory'] is bool
          ? json['isMandatory'] as bool
          : (json['is_mandatory'] as bool? ?? false),
      minSumInsured: (json['minSumInsured'] ?? json['min_sum_insured']) != null
          ? double.tryParse(
              (json['minSumInsured'] ?? json['min_sum_insured']).toString(),
            )
          : null,
      maxSumInsured: (json['maxSumInsured'] ?? json['max_sum_insured']) != null
          ? double.tryParse(
              (json['maxSumInsured'] ?? json['max_sum_insured']).toString(),
            )
          : null,
    );
  }
}

class ProductVersion {
  final String id;
  final int versionNumber;
  final String status;
  final String effectiveFrom;
  final String? effectiveTo;
  final List<CoverageOption> coverageOptions;

  const ProductVersion({
    required this.id,
    required this.versionNumber,
    required this.status,
    required this.effectiveFrom,
    this.effectiveTo,
    required this.coverageOptions,
  });

  factory ProductVersion.fromJson(Map<String, dynamic> json) {
    final rawCoverages = json['coverageOptions'] ?? json['coverage_options'];
    final coverages = (rawCoverages is List)
        ? rawCoverages
              .cast<Map<String, dynamic>>()
              .map(CoverageOption.fromJson)
              .toList()
        : <CoverageOption>[];

    return ProductVersion(
      id: (json['id'] ?? '').toString(),
      versionNumber:
          (json['versionNumber'] ?? json['version_number'] ?? 1) is num
          ? (json['versionNumber'] ?? json['version_number'] ?? 1).toInt()
          : int.tryParse(
                  (json['versionNumber'] ?? json['version_number'] ?? 1)
                      .toString(),
                ) ??
                1,
      status: (json['status'] ?? 'DRAFT').toString(),
      effectiveFrom: (json['effectiveFrom'] ?? json['effective_from'] ?? '')
          .toString(),
      effectiveTo:
          json['effectiveTo']?.toString() ?? json['effective_to']?.toString(),
      coverageOptions: coverages,
    );
  }
}

class Product {
  final String id;
  final String name;
  final String code;
  final String type;
  final String? description;
  final bool isActive;
  final List<ProductVersion> versions;

  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.description,
    required this.isActive,
    required this.versions,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawVersions = json['versions'];
    final versions = (rawVersions is List)
        ? rawVersions
              .cast<Map<String, dynamic>>()
              .map(ProductVersion.fromJson)
              .toList()
        : <ProductVersion>[];

    return Product(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Product').toString(),
      code: (json['code'] ?? '').toString(),
      type: (json['type'] ?? 'GENERAL').toString(),
      description: json['description']?.toString(),
      isActive: json['isActive'] as bool? ?? json['active'] as bool? ?? true,
      versions: versions,
    );
  }
}

class RiskProfile {
  final String id;
  final String applicantRef;
  final String riskBand;
  final String loadingPercentage;
  final Map<String, dynamic> profileData;

  const RiskProfile({
    required this.id,
    required this.applicantRef,
    required this.riskBand,
    required this.loadingPercentage,
    required this.profileData,
  });

  factory RiskProfile.fromJson(Map<String, dynamic> json) {
    return RiskProfile(
      id: (json['id'] ?? '').toString(),
      applicantRef: (json['applicantRef'] ?? json['applicant_ref'] ?? 'Unknown')
          .toString(),
      riskBand: (json['riskBand'] ?? json['risk_band'] ?? 'STANDARD')
          .toString(),
      loadingPercentage:
          (json['loadingPercentage'] ?? json['loading_percentage'] ?? '0.00')
              .toString(),
      profileData:
          json['profileData'] as Map<String, dynamic>? ??
          json['profile_data'] as Map<String, dynamic>? ??
          {},
    );
  }
}

class InsuranceRule {
  final String id;
  final String name;
  final String type; // pricing, eligibility, etc.
  final Map<String, dynamic> logic;

  const InsuranceRule({
    required this.id,
    required this.name,
    required this.type,
    required this.logic,
  });

  factory InsuranceRule.fromJson(Map<String, dynamic> json, String type) {
    return InsuranceRule(
      id: (json['ruleId'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed Rule').toString(),
      type: type,
      logic:
          json['ruleDefinition'] as Map<String, dynamic>? ??
          json['rule_definition'] as Map<String, dynamic>? ??
          json['ruleLogic'] as Map<String, dynamic>? ??
          json['rule_logic'] as Map<String, dynamic>? ??
          json['ruleExpression'] as Map<String, dynamic>? ??
          json['rule_expression'] as Map<String, dynamic>? ??
          {},
    );
  }
}

// Quote model is now imported from ../models/quote.dart

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Fetches all users from GET /users. Returns empty list on error.
final usersProvider = FutureProvider.autoDispose<List<AdminUser>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('users');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(AdminUser.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Users fetch error: $e');
    return [];
  }
});

/// Fetches all tenants from GET /tenants. Returns empty list on error.
final tenantsProvider = FutureProvider.autoDispose<List<Tenant>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('tenants');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(Tenant.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Tenants fetch error: $e');
    return [];
  }
});

/// Fetches today's processed payouts from GET /payouts/processed-today.
/// Returns null on error so the UI can show "—".
final processedTodayProvider = FutureProvider.autoDispose<ProcessedTodayStats?>(
  (ref) async {
    try {
      final client = ref.watch(apiClientProvider);
      final res = await client.get('payouts/processed-today');
      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        return ProcessedTodayStats.fromJson(res.data as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      debugPrint('Processed today fetch error: $e');
      return null;
    }
  },
);

/// Fetches all products from GET /products.
final productsProvider = FutureProvider.autoDispose<List<Product>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('products');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Products fetch error: $e');
    return [];
  }
});

/// Fetches rules for a specific product version.
final rulesProvider = FutureProvider.autoDispose
    .family<Map<String, List<InsuranceRule>>, String>((
      ref,
      productVersionId,
    ) async {
      try {
        final client = ref.watch(apiClientProvider);
        final auth = ref.watch(authNotifierProvider);
        final tenantId = auth.user?.tenantId ?? ApiConstants.defaultTenantId;
        final res = await client.get(
          'rules',
          queryParameters: {
            'productVersionId': productVersionId,
            'tenantId': tenantId,
          },
        );
        if (res.statusCode == 200 && res.data is Map) {
          final data = res.data as Map<String, dynamic>;
          final eligibility =
              (data['eligibility'] as List?)
                  ?.cast<Map<String, dynamic>>()
                  .map((j) => InsuranceRule.fromJson(j, 'eligibility'))
                  .toList() ??
              [];
          final pricing =
              (data['pricing'] as List?)
                  ?.cast<Map<String, dynamic>>()
                  .map((j) => InsuranceRule.fromJson(j, 'pricing'))
                  .toList() ??
              [];
          return {'eligibility': eligibility, 'pricing': pricing};
        }
        return {'eligibility': [], 'pricing': []};
      } catch (e) {
        debugPrint('Rules fetch error: $e');
        return {'eligibility': [], 'pricing': []};
      }
    });

/// Fetches all quotes from GET /quotes.
final quotesProvider = FutureProvider.autoDispose<List<Quote>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    // Note: We'll eventually need to pass the tenant ID via headers as implemented in the controller.
    // The ApiClient should handle this if it has the current tenant in its state/interceptors.
    final res = await client.get('quotes');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(Quote.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Quotes fetch error: $e');
    return [];
  }
});

class SlaStats {
  final String process;
  final String target;
  final String met;
  final String status;

  const SlaStats({
    required this.process,
    required this.target,
    required this.met,
    required this.status,
  });

  factory SlaStats.fromJson(Map<String, dynamic> json) {
    return SlaStats(
      process: json['process'] as String,
      target: json['target'] as String,
      met: json['met'] as String,
      status: json['status'] as String,
    );
  }
}

final slaProvider = FutureProvider.autoDispose<List<SlaStats>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('sla/stats');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(SlaStats.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('SLA fetch error: $e');
    return [];
  }
});

/// Fetches all risk profiles from GET /risk.
final riskProfilesProvider = FutureProvider.autoDispose<List<RiskProfile>>((
  ref,
) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('risk');
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(RiskProfile.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Risk profiles fetch error: $e');
    return [];
  }
});

// Notification config: see notification_config_provider.dart
