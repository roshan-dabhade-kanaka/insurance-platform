import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../widgets/widgets.dart';

import '../models/audit.dart';
import '../providers/audit_provider.dart';

/// Compliance Audit Logs: Quote History, Claim History, Underwriting Decisions,
/// Payout Authorization, Workflow State Changes. List-based UI to handle
/// overflow and provide intuitive experience.
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
                  // Using Wrap with proper spacing to solve the overflow from the image
                  Wrap(
                    spacing: 16,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 220),
                        child: DropdownButtonFormField<AuditEntityFilter>(
                          value: _entityFilter,
                          isExpanded:
                              true, // Prevents overflow inside the button
                          decoration: const InputDecoration(
                            labelText: 'Entity',
                            isDense: true,
                          ),
                          items: AuditEntityFilter.values
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    e.label,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) {
                            if (v != null) setState(() => _entityFilter = v);
                          },
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 200),
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
            data: (listState) => _AuditList(
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
                return _AuditList(
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

class _AuditList extends StatelessWidget {
  const _AuditList({
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
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Row(
              children: [
                Text(
                  'Audit Entries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$totalElements total',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (logs.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: Text('No audit entries found.')),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final log = logs[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  leading: CircleAvatar(
                    backgroundColor: _getEntityColor(
                      log.entityType,
                      theme,
                    ).withValues(alpha: 0.1),
                    child: Icon(
                      _getEntityIcon(log.entityType),
                      color: _getEntityColor(log.entityType, theme),
                      size: 20,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(
                        _entityLabel(log.entityType),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          log.action,
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        'ID: ${log.entityId} • By: ${log.changedBy ?? "System"}',
                        style: theme.textTheme.bodySmall,
                      ),
                      if (log.oldState != null || log.newState != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.swap_horiz,
                              size: 14,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${log.oldState ?? "–"} → ${log.newState ?? "–"}',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                  trailing: Text(
                    _timeFormat.format(log.occurredAt.toLocal()),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.all(16),
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
                    'Page ${page + 1} of ${(totalElements / pageSize).ceil()}',
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

  IconData _getEntityIcon(String type) {
    if (type.contains('QUOTE')) return Icons.description_outlined;
    if (type.contains('CLAIM')) return Icons.assignment_outlined;
    if (type.contains('UW_CASE')) return Icons.gavel_outlined;
    if (type.contains('PAYOUT')) return Icons.payments_outlined;
    if (type.contains('WORKFLOW')) return Icons.account_tree_outlined;
    return Icons.history;
  }

  Color _getEntityColor(String type, ThemeData theme) {
    if (type.contains('QUOTE')) return Colors.blue;
    if (type.contains('CLAIM')) return Colors.orange;
    if (type.contains('UW_CASE')) return Colors.purple;
    if (type.contains('PAYOUT')) return Colors.green;
    return theme.colorScheme.primary;
  }
}
