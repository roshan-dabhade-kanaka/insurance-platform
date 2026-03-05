import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/widgets.dart';

import '../models/audit.dart';
import '../providers/audit_provider.dart';

/// Compliance Audit Logs: Quote History, Claim History, Underwriting Decisions,
/// Payout Authorization, Workflow State Changes. Paginated DataTable with
/// filters: Entity, User, Date range.
class ComplianceAuditLogsPage extends ConsumerStatefulWidget {
  const ComplianceAuditLogsPage({super.key});

  @override
  ConsumerState<ComplianceAuditLogsPage> createState() =>
      _ComplianceAuditLogsPageState();
}

class _ComplianceAuditLogsPageState
    extends ConsumerState<ComplianceAuditLogsPage> {
  final _userFilterController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;
  AuditEntityFilter _entityFilter = AuditEntityFilter.all;
  static const int _pageSize = 20;
  final _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _userFilterController.dispose();
    super.dispose();
  }

  void _load() {
    ref
        .read(auditProvider.notifier)
        .fetchPage(
          page: 0,
          pageSize: _pageSize,
          entityType: _entityFilter.entityType,
          changedBy: _userFilterController.text.trim().isEmpty
              ? null
              : _userFilterController.text.trim(),
          fromDate: _fromDate,
          toDate: _toDate,
        );
  }

  void _applyFilters() {
    ref
        .read(auditProvider.notifier)
        .applyFilters(
          entityType: _entityFilter.entityType,
          changedBy: _userFilterController.text.trim().isEmpty
              ? null
              : _userFilterController.text.trim(),
          fromDate: _fromDate,
          toDate: _toDate,
        );
  }

  void _pickFromDate() async {
    final initial = _fromDate ?? DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'From date',
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 320,
                    child: CalendarDatePicker(
                      initialDate: initial,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onDateChanged: (d) => Navigator.of(ctx).pop(d),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _fromDate = picked);
  }

  void _pickToDate() async {
    final initial = _toDate ?? _fromDate ?? DateTime.now();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (ctx) {
        final t = Theme.of(ctx);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 360),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'To date',
                  style: t.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 320,
                    child: CalendarDatePicker(
                      initialDate: initial,
                      firstDate: _fromDate ?? DateTime(2020),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      onDateChanged: (d) => Navigator.of(ctx).pop(d),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _toDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final auditState = ref.watch(auditProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Audit logs track all critical system events including quote history, claim history, underwriting decisions, and workflow state changes.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Filters',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<AuditEntityFilter>(
                          value: _entityFilter,
                          decoration: const InputDecoration(
                            labelText: 'Entity',
                            isDense: true,
                          ),
                          items: AuditEntityFilter.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(e.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _entityFilter = v);
                          },
                        ),
                      ),
                      SizedBox(
                        width: 200,
                        child: TextField(
                          controller: _userFilterController,
                          decoration: const InputDecoration(
                            labelText: 'User',
                            hintText: 'Filter by user',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _applyFilters(),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickFromDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _fromDate != null
                              ? _dateFormat.format(_fromDate!)
                              : 'From date',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: _pickToDate,
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(
                          _toDate != null
                              ? _dateFormat.format(_toDate!)
                              : 'To date',
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: auditState.isLoading ? null : _applyFilters,
                        icon: const Icon(Icons.search, size: 20),
                        label: const Text('Apply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          auditState.when(
            data: (listState) => _AuditDataTable(
              logs: listState.logs,
              totalElements: listState.totalElements,
              page: listState.page,
              pageSize: listState.pageSize,
              onPageChanged: (page) {
                ref.read(auditProvider.notifier).goToPage(page);
              },
            ),
            loading: () {
              final prev = auditState.valueOrNull;
              if (prev != null) {
                return _AuditDataTable(
                  logs: prev.logs,
                  totalElements: prev.totalElements,
                  page: prev.page,
                  pageSize: prev.pageSize,
                  onPageChanged: (p) =>
                      ref.read(auditProvider.notifier).goToPage(p),
                );
              }
              return const Center(
                child: Padding(padding: EdgeInsets.all(32), child: AppLoader()),
              );
            },
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Failed to load audit logs',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      e.toString(),
                      style: theme.textTheme.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuditDataTable extends StatelessWidget {
  const _AuditDataTable({
    required this.logs,
    required this.totalElements,
    required this.page,
    required this.pageSize,
    required this.onPageChanged,
  });

  final List<AuditLog> logs;
  final int totalElements;
  final int page;
  final int pageSize;
  final void Function(int) onPageChanged;

  static final _timeFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final start = page * pageSize + 1;
    final end = (start + logs.length - 1).clamp(0, totalElements);

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                Text(
                  'Audit entries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$totalElements total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('Timestamp')),
                DataColumn(label: Text('Entity')),
                DataColumn(label: Text('Entity ID')),
                DataColumn(label: Text('Action')),
                DataColumn(label: Text('State change')),
                DataColumn(label: Text('User')),
              ],
              rows: logs
                  .map(
                    (l) => DataRow(
                      cells: [
                        DataCell(
                          Text(_timeFormat.format(l.occurredAt.toLocal())),
                        ),
                        DataCell(Text(_entityLabel(l.entityType))),
                        DataCell(
                          Text(
                            l.entityId.length > 12
                                ? '${l.entityId.substring(0, 12)}…'
                                : l.entityId,
                          ),
                        ),
                        DataCell(Text(l.action)),
                        DataCell(
                          Text('${l.oldState ?? "–"} → ${l.newState ?? "–"}'),
                        ),
                        DataCell(Text(l.changedBy ?? '–')),
                      ],
                    ),
                  )
                  .toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Text(
                  totalElements == 0
                      ? '0 entries'
                      : '$start–$end of $totalElements',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (totalElements > pageSize) ...[
                  IconButton(
                    onPressed: page > 0 ? () => onPageChanged(page - 1) : null,
                    icon: const Icon(Icons.chevron_left),
                    tooltip: 'Previous page',
                  ),
                  Text(
                    'Page ${page + 1} of ${(totalElements / pageSize).ceil().clamp(1, totalElements)}',
                    style: theme.textTheme.bodySmall,
                  ),
                  IconButton(
                    onPressed: (page + 1) * pageSize < totalElements
                        ? () => onPageChanged(page + 1)
                        : null,
                    icon: const Icon(Icons.chevron_right),
                    tooltip: 'Next page',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _entityLabel(String type) {
    final f = AuditEntityFilter.values.cast<AuditEntityFilter?>().firstWhere(
      (e) => e!.entityType == type,
      orElse: () => null,
    );
    return f?.label ?? type;
  }
}
