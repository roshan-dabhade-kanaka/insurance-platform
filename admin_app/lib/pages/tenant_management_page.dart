import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/admin_providers.dart';
import '../theme/app_theme.dart';

/// Tenant Management — fetches from GET /tenants via tenantsProvider.
class TenantManagementPage extends ConsumerWidget {
  const TenantManagementPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantsAsync = ref.watch(tenantsProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(message: 'All tenants provisioned in the platform.'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => ref.refresh(tenantsProvider),
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Refresh table'),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
          ),
          const SizedBox(height: 8),
          tenantsAsync.when(
            loading: () => const Center(
              child: Padding(padding: EdgeInsets.all(48), child: AppLoader()),
            ),
            error: (err, _) => _ErrorCard(
              message: err.toString(),
              onRetry: () => ref.refresh(tenantsProvider),
            ),
            data: (tenants) {
              if (tenants.isEmpty) {
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(48),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.business_outlined,
                          size: 48,
                          color: theme.colorScheme.onSurfaceVariant.withValues(
                            alpha: 0.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No tenants found',
                          style: theme.textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                );
              }
              return Card(
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: double.infinity,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minWidth: MediaQuery.of(context).size.width - 80,
                      ),
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          AppTheme.primaryColor.withValues(alpha: 0.07),
                        ),
                        horizontalMargin: 24,
                        columnSpacing: 24,
                        columns: const [
                          DataColumn(label: Text('Name')),
                          DataColumn(label: Text('Plan')),
                          DataColumn(label: Text('Status')),
                          DataColumn(label: Text('ID')),
                        ],
                        rows: tenants
                            .map(
                              (t) => DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      t.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  DataCell(Text(t.plan ?? '-')),
                                  DataCell(
                                    Chip(
                                      label: Text(
                                        t.isActive ? 'Active' : 'Inactive',
                                      ),
                                      backgroundColor: t.isActive
                                          ? Colors.green.withValues(alpha: 0.15)
                                          : Colors.red.withValues(alpha: 0.15),
                                      labelStyle: TextStyle(
                                        color: t.isActive
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                      padding: EdgeInsets.zero,
                                    ),
                                  ),
                                  DataCell(
                                    Tooltip(
                                      message: t.id,
                                      child: Text(
                                        t.id.length > 8
                                            ? '${t.id.substring(0, 8)}…'
                                            : t.id,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: 12),
            Text('Failed to load', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
