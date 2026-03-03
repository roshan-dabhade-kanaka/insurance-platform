import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';

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

class Product {
  final String id;
  final String name;
  final String code;
  final String type;
  final String? description;
  final bool isActive;

  const Product({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.description,
    required this.isActive,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unknown Product').toString(),
      code: (json['code'] ?? '').toString(),
      type: (json['type'] ?? 'GENERAL').toString(),
      description: json['description']?.toString(),
      isActive: json['isActive'] as bool? ?? true,
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
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? 'Unnamed Rule').toString(),
      type: type,
      logic:
          json['rule_logic'] as Map<String, dynamic>? ??
          json['rule_expression'] as Map<String, dynamic>? ??
          {},
    );
  }
}

class Quote {
  final String id;
  final String quoteNumber;
  final String productVersionId;
  final String status;
  final String applicantRef;
  final String tenantId;

  const Quote({
    required this.id,
    required this.quoteNumber,
    required this.productVersionId,
    required this.status,
    required this.applicantRef,
    required this.tenantId,
  });

  factory Quote.fromJson(Map<String, dynamic> json) {
    return Quote(
      id: (json['id'] ?? '').toString(),
      quoteNumber: (json['quoteNumber'] ?? json['quote_number'] ?? '')
          .toString(),
      productVersionId:
          (json['productVersionId'] ?? json['product_version_id'] ?? '')
              .toString(),
      status: (json['status'] ?? 'DRAFT').toString(),
      applicantRef: (json['applicantRef'] ?? json['applicant_ref'] ?? '')
          .toString(),
      tenantId: (json['tenantId'] ?? json['tenant_id'] ?? '').toString(),
    );
  }
}

// ---------------------------------------------------------------------------
// Providers
// ---------------------------------------------------------------------------

/// Fetches all users from GET /users. Returns empty list on error.
final usersProvider = FutureProvider<List<AdminUser>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/users');
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
final tenantsProvider = FutureProvider<List<Tenant>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/tenants');
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
final processedTodayProvider = FutureProvider<ProcessedTodayStats?>((
  ref,
) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/payouts/processed-today');
    if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
      return ProcessedTodayStats.fromJson(res.data as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    debugPrint('Processed today fetch error: $e');
    return null;
  }
});

/// Fetches all products from GET /products.
final productsProvider = FutureProvider<List<Product>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/products');
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

/// Fetches all rules from GET /rules.
final rulesProvider = FutureProvider<Map<String, List<InsuranceRule>>>((
  ref,
) async {
  try {
    final client = ref.watch(apiClientProvider);
    // Note: This expects a specific tenantId and productVersionId which we might need to parameterize later.
    // For now, using query params if available or defaults.
    final res = await client.get(
      '/rules',
      queryParameters: {
        'tenantId': '00000000-0000-0000-0000-000000000001',
        'productVersionId': '00000000-0000-0000-0000-000000000001',
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
final quotesProvider = FutureProvider<List<Quote>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    // Note: We'll eventually need to pass the tenant ID via headers as implemented in the controller.
    // The ApiClient should handle this if it has the current tenant in its state/interceptors.
    final res = await client.get('/quotes');
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

final slaProvider = FutureProvider<List<SlaStats>>((ref) async {
  try {
    final client = ref.watch(apiClientProvider);
    final res = await client.get('/sla/stats');
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

// Notification config: see notification_config_provider.dart
