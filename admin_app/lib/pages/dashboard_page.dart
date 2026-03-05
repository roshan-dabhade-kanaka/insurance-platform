import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/dashboard_api.dart';
import '../widgets/widgets.dart';

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
            const Padding(padding: EdgeInsets.only(top: 8), child: AppLoader()),
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
                    color: Colors.blue.shade600,
                  ),
                  _MetricCard(
                    icon: Icons.payments_outlined,
                    label: isCustomer ? 'My Premiums' : 'Premiums',
                    value: stats != null ? stats.premiumsFormatted : '—',
                    trend: stats != null ? 'Live' : '—',
                    trendUp: true,
                    color: Colors.teal.shade600,
                  ),
                  _MetricCard(
                    icon: Icons.assignment_late_outlined,
                    label: isCustomer ? 'My Pending Claims' : 'Pending Claims',
                    value: stats != null
                        ? _formatInt(stats.pendingClaims)
                        : '—',
                    trend: stats != null ? 'Live' : '—',
                    trendUp: true,
                    color: Colors.orange.shade600,
                  ),
                  _MetricCard(
                    icon: Icons.hourglass_empty_outlined,
                    label: isCustomer ? 'UW Queue' : 'UW Queue',
                    value: isCustomer
                        ? '—'
                        : (stats != null ? _formatInt(stats.uwQueue) : '—'),
                    trend: isCustomer ? 'N/A' : (stats != null ? 'Live' : '—'),
                    trendUp: true,
                    color: Colors.indigo.shade600,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Trends',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Revenue growth over last 6 months',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withValues(
                            alpha: 0.3,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'Last 6 Months',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  trendsAsync.when(
                    loading: () =>
                        const SizedBox(height: 180, child: AppLoader()),
                    error: (_, _e) => const SizedBox(
                      height: 180,
                      child: Center(
                        child: Text(
                          'Could not load trend data',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                    data: (trends) {
                      if (trends.isEmpty) {
                        return const SizedBox(
                          height: 180,
                          child: Center(child: Text('No trend data available')),
                        );
                      }
                      final maxAmount = trends
                          .map((t) => t.amount)
                          .reduce((a, b) => a > b ? a : b);
                      return SizedBox(
                        height: 180,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: trends.map((t) {
                            final barH = maxAmount > 0
                                ? (t.amount / maxAmount * 140).clamp(
                                    12.0,
                                    140.0,
                                  )
                                : 12.0;
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                Tooltip(
                                  message: '₹${t.amount.toStringAsFixed(2)}',
                                  child: Container(
                                    width: 40,
                                    height: barH,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          theme.colorScheme.primary,
                                          theme.colorScheme.primary.withValues(
                                            alpha: 0.6,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.colorScheme.primary
                                              .withValues(alpha: 0.2),
                                          blurRadius: 8,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  t.label,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final String trend;
  final bool trendUp;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    label.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.onSurfaceVariant,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
            Row(
              children: [
                Icon(
                  trendUp ? Icons.trending_up : Icons.trending_down,
                  size: 14,
                  color: trendUp ? Colors.green.shade600 : Colors.red.shade600,
                ),
                const SizedBox(width: 4),
                Text(
                  trend,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: trendUp
                        ? Colors.green.shade700
                        : Colors.red.shade700,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
