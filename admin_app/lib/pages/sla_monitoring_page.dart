import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/admin_providers.dart';

/// SLA monitoring dashboard (from sla_monitoring_dashboard).
class SLAMonitoringPage extends ConsumerWidget {
  const SLAMonitoringPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slaAsync = ref.watch(slaProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          slaAsync.when(
            data: (stats) => PaginatedDataTableWidget(
              title: 'SLA Status',
              columns: const [
                DataColumn(label: Text('Process')),
                DataColumn(label: Text('Target')),
                DataColumn(label: Text('Met')),
                DataColumn(label: Text('Status')),
              ],
              rows: stats
                  .map(
                    (s) => DataRow(
                      cells: [
                        DataCell(Text(s.process)),
                        DataCell(Text(s.target)),
                        DataCell(Text(s.met)),
                        DataCell(
                          Chip(
                            label: Text(
                              s.status,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor: s.status.toLowerCase() == 'ok'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  )
                  .toList(),
            ),
            loading: () => const AppLoader(),
            error: (e, _) => Center(child: Text('Error loading SLA data: $e')),
          ),
        ],
      ),
    );
  }
}
