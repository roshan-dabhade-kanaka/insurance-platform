import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dashboard_api.dart';
import '../theme/app_theme.dart';

String _formatInt(int n) {
  final s = n.toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
    buf.write(s[i]);
  }
  return buf.toString();
}

/// Executive summary and KPI cards; data from backend when available.
class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statsAsync = ref.watch(dashboardStatsProvider);
    final trendsAsync = ref.watch(premiumTrendsProvider);
    final isCustomer = ref.watch(isCustomerDashboardProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isCustomer ? 'Your Overview' : 'Executive Summary',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isCustomer
                ? 'Your policies and claims at a glance'
                : 'System overview',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (statsAsync.hasValue &&
              statsAsync.value == null &&
              !statsAsync.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Connect backend for live data',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
            ),
          if (statsAsync.isLoading)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 800
                  ? 4
                  : (constraints.maxWidth > 500 ? 2 : 1);
              final stats = statsAsync.valueOrNull;
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.4,
                children: [
                  _MetricCard(
                    icon: Icons.verified_user_outlined,
                    label: isCustomer ? 'My Policies' : 'Active Policies',
                    value: stats != null
                        ? _formatInt(stats.activePolicies)
                        : '—',
                    trend: stats != null ? 'Live' : '—',
                    trendUp: true,
                  ),
                  _MetricCard(
                    icon: Icons.payments_outlined,
                    label: isCustomer ? 'My Premiums' : 'Premiums',
                    value: stats != null ? stats.premiumsFormatted : '—',
                    trend: stats != null ? 'Live' : '—',
                    trendUp: true,
                  ),
                  _MetricCard(
                    icon: Icons.assignment_late_outlined,
                    label: isCustomer ? 'My Pending Claims' : 'Pending Claims',
                    value: stats != null
                        ? _formatInt(stats.pendingClaims)
                        : '—',
                    trend: stats != null ? 'Live' : '—',
                    trendUp: true,
                  ),
                  _MetricCard(
                    icon: Icons.hourglass_empty_outlined,
                    label: isCustomer ? 'UW Queue' : 'UW Queue',
                    value: isCustomer
                        ? '—'
                        : (stats != null ? _formatInt(stats.uwQueue) : '—'),
                    trend: isCustomer ? 'N/A' : (stats != null ? 'Live' : '—'),
                    trendUp: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Premium Trends',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'Last 6 Months',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  trendsAsync.when(
                    loading: () => const SizedBox(
                      height: 120,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    error: (_, _e) => const SizedBox(
                      height: 120,
                      child: Center(child: Text('Could not load trend data')),
                    ),
                    data: (trends) {
                      if (trends.isEmpty) {
                        return const SizedBox(
                          height: 120,
                          child: Center(child: Text('No trend data available')),
                        );
                      }
                      final maxAmount = trends
                          .map((t) => t.amount)
                          .reduce((a, b) => a > b ? a : b);
                      return SizedBox(
                        height: 140,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: trends.map((t) {
                            final barH = maxAmount > 0
                                ? (t.amount / maxAmount * 100).clamp(8.0, 100.0)
                                : 8.0;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Container(
                                  width: 32,
                                  height: barH,
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.7,
                                    ),
                                    borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  t.label,
                                  style: theme.textTheme.labelSmall,
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.trend,
    required this.trendUp,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trend;
  final bool trendUp;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppTheme.primaryColor),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              trend,
              style: theme.textTheme.labelMedium?.copyWith(
                color: trendUp ? Colors.green : Colors.red,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
