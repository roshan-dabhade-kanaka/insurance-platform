import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api_client.dart';
import 'constants.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_model.dart';
import '../auth/app_role.dart';

class DashboardStats {
  final int activePolicies;
  final double totalPremiums;
  final int pendingClaims;
  final int uwQueue;

  const DashboardStats({
    required this.activePolicies,
    required this.totalPremiums,
    required this.pendingClaims,
    required this.uwQueue,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      activePolicies: (json['activePolicies'] as num?)?.toInt() ?? 0,
      totalPremiums: (json['totalPremiums'] as num?)?.toDouble() ?? 0,
      pendingClaims: (json['pendingClaims'] as num?)?.toInt() ?? 0,
      uwQueue: (json['uwQueue'] as num?)?.toInt() ?? 0,
    );
  }

  String get premiumsFormatted {
    if (totalPremiums >= 1e6) {
      return '₹${(totalPremiums / 1e6).toStringAsFixed(1)}M';
    }
    if (totalPremiums >= 1e3) {
      return '₹${(totalPremiums / 1e3).toStringAsFixed(1)}K';
    }
    return '₹${totalPremiums.toStringAsFixed(0)}';
  }
}

/// One bar in the premium trend chart.
class PremiumTrendPoint {
  final String label; // e.g. "Jan", "Feb"
  final double amount;

  const PremiumTrendPoint({required this.label, required this.amount});

  factory PremiumTrendPoint.fromJson(Map<String, dynamic> json) {
    return PremiumTrendPoint(
      label: (json['label'] ?? json['month'] ?? '').toString(),
      amount: (json['amount'] ?? json['total'] ?? 0) is num
          ? ((json['amount'] ?? json['total']) as num).toDouble()
          : 0,
    );
  }
}

/// True when the current user should see customer-scoped dashboard (my policies, my claims).
bool isCustomerDashboardScope(AuthUser user) {
  final roles = user.roles;
  if (roles.isEmpty) return false;
  final onlyCustomer = roles.length == 1 && roles.contains(AppRole.customer);
  final hasCustomer = roles.contains(AppRole.customer);
  final hasAnyStaff = roles.any((r) => r != AppRole.customer);
  return onlyCustomer || (hasCustomer && !hasAnyStaff);
}

final isCustomerDashboardProvider = Provider<bool>((ref) {
  ref.watch(authVersionProvider);
  final auth = ref.watch(authNotifierProvider);
  final user = auth.user;
  if (user == null) return false;
  return isCustomerDashboardScope(user);
});

final dashboardStatsProvider = FutureProvider<DashboardStats?>((ref) async {
  ref.watch(authVersionProvider);
  try {
    final authState = ref.watch(authNotifierProvider).state;
    String tenantId = ApiConstants.defaultTenantId;
    bool useCustomerScope = false;

    if (authState is AuthAuthenticated) {
      tenantId = authState.user.tenantId;
      useCustomerScope = isCustomerDashboardScope(authState.user);
    }

    final client = ref.watch(apiClientProvider);
    final path = useCustomerScope ? 'dashboard/stats/me' : 'dashboard/stats';
    final res = await client.get(path, queryParameters: {'tenantId': tenantId});
    if (res.statusCode == 200 && res.data != null) {
      return DashboardStats.fromJson(res.data as Map<String, dynamic>);
    }
    return null;
  } catch (e) {
    debugPrint('Dashboard stats error: $e');
    return null;
  }
});

/// Premium trend data for the bar chart. Returns empty list on error.
final premiumTrendsProvider = FutureProvider<List<PremiumTrendPoint>>((
  ref,
) async {
  try {
    final authState = ref.watch(authNotifierProvider).state;
    String tenantId = ApiConstants.defaultTenantId;
    if (authState is AuthAuthenticated) {
      tenantId = authState.user.tenantId;
    }
    final client = ref.watch(apiClientProvider);
    final res = await client.get(
      'dashboard/premium-trends',
      queryParameters: {'tenantId': tenantId},
    );
    if (res.statusCode == 200 && res.data is List) {
      return (res.data as List)
          .cast<Map<String, dynamic>>()
          .map(PremiumTrendPoint.fromJson)
          .toList();
    }
    return [];
  } catch (e) {
    debugPrint('Premium trends error: $e');
    return [];
  }
});
