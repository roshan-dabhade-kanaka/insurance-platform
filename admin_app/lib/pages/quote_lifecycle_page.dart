import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quote_provider.dart';
import '../auth/auth_provider.dart';
import '../models/quote.dart';
import '../widgets/widgets.dart';
import '../core/error_handler.dart';

// ─── Filter & Sort State ─────────────────────────────────────────────────────

enum QuoteSortField { createdAt, quoteNumber, status }

enum QuoteSortDir { asc, desc }

class _FilterState {
  final String search;
  final String statusFilter; // '' = all
  final QuoteSortField sort;
  final QuoteSortDir dir;

  const _FilterState({
    this.search = '',
    this.statusFilter = '',
    this.sort = QuoteSortField.createdAt,
    this.dir = QuoteSortDir.desc,
  });

  _FilterState copyWith({
    String? search,
    String? statusFilter,
    QuoteSortField? sort,
    QuoteSortDir? dir,
  }) {
    return _FilterState(
      search: search ?? this.search,
      statusFilter: statusFilter ?? this.statusFilter,
      sort: sort ?? this.sort,
      dir: dir ?? this.dir,
    );
  }
}

// ─── Page ────────────────────────────────────────────────────────────────────

class QuoteLifecyclePage extends ConsumerStatefulWidget {
  const QuoteLifecyclePage({super.key});

  @override
  ConsumerState<QuoteLifecyclePage> createState() => _QuoteLifecyclePageState();
}

class _QuoteLifecyclePageState extends ConsumerState<QuoteLifecyclePage> {
  final _searchController = TextEditingController();
  _FilterState _filters = const _FilterState();

  static const _allStatuses = [
    '',
    'DRAFT',
    'SUBMITTED',
    'APPROVED',
    'REJECTED',
    'CANCELLED',
    'ISSUED',
    'EXPIRED',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(quoteProvider.notifier).fetchQuotes();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Quote> _applyFilters(List<Quote> quotes) {
    var list = quotes.toList();

    // Search
    final q = _filters.search.toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((qt) {
        return qt.quoteNumber.toLowerCase().contains(q) ||
            qt.id.toLowerCase().contains(q) ||
            (qt.applicantSnapshot['email'] ?? qt.applicantRef ?? '')
                .toString()
                .toLowerCase()
                .contains(q);
      }).toList();
    }

    // Status
    if (_filters.statusFilter.isNotEmpty) {
      list = list
          .where(
            (qt) =>
                qt.status.toUpperCase() == _filters.statusFilter.toUpperCase(),
          )
          .toList();
    }

    // Sort
    list.sort((a, b) {
      int cmp;
      switch (_filters.sort) {
        case QuoteSortField.quoteNumber:
          cmp = a.quoteNumber.compareTo(b.quoteNumber);
        case QuoteSortField.status:
          cmp = a.status.compareTo(b.status);
        case QuoteSortField.createdAt:
          cmp = a.createdAt.compareTo(b.createdAt);
      }
      return _filters.dir == QuoteSortDir.asc ? cmp : -cmp;
    });

    return list;
  }

  Color _statusColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return const Color(0xFFF59E0B);
      case 'SUBMITTED':
        return const Color(0xFF3B82F6);
      case 'APPROVED':
        return const Color(0xFF10B981);
      case 'ISSUED':
        return const Color(0xFF059669);
      case 'REJECTED':
      case 'CANCELLED':
        return const Color(0xFFEF4444);
      case 'EXPIRED':
        return const Color(0xFF6B7280);
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return Icons.edit_note_outlined;
      case 'SUBMITTED':
        return Icons.send_outlined;
      case 'APPROVED':
      case 'ISSUED':
        return Icons.check_circle_outline;
      case 'REJECTED':
        return Icons.cancel_outlined;
      case 'CANCELLED':
        return Icons.block_outlined;
      case 'EXPIRED':
        return Icons.timer_off_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  void _showActionDialog(BuildContext context, Quote quote) {
    showDialog(
      context: context,
      builder: (ctx) => _QuoteActionDialog(
        quote: quote,
        statusColor: _statusColor(quote.status),
        statusIcon: _statusIcon(quote.status),
        onAction: (action) async {
          Navigator.of(ctx).pop();
          final notifier = ref.read(quoteProvider.notifier);
          final user = ref.read(authNotifierProvider).user;
          final userId = user?.id ?? 'admin';

          try {
            if (action == 'submit') {
              await notifier.submitQuote(quote.id);
              if (context.mounted) {
                ResponseHandler.showSuccess(
                  context,
                  'Quote submitted for underwriting',
                );
              }
            } else if (action == 'cancel') {
              await notifier.cancelQuote(quote.id, userId, 'Cancelled by user');
              if (context.mounted) {
                ResponseHandler.showSuccess(context, 'Quote cancelled');
              }
            } else if (action == 'copy_id') {
              await Clipboard.setData(ClipboardData(text: quote.id));
              if (context.mounted) {
                ResponseHandler.showSuccess(
                  context,
                  'Quote ID copied to clipboard',
                );
              }
            }
          } catch (e) {
            if (context.mounted) {
              ResponseHandler.showError(context, e, fallback: 'Action failed');
            }
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final quoteState = ref.watch(quoteProvider);
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Top bar ──────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const InfoBox(
                message:
                    'All quotes are listed below. Click on any quote to submit it for underwriting, cancel it, or copy its ID.',
              ),
              const SizedBox(height: 16),
              // Search bar
              TextField(
                controller: _searchController,
                onChanged: (v) =>
                    setState(() => _filters = _filters.copyWith(search: v)),
                decoration: InputDecoration(
                  hintText: 'Search by quote number, ID, or email…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _filters.search.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            setState(
                              () => _filters = _filters.copyWith(search: ''),
                            );
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              // Filter + Sort row
              Row(
                children: [
                  // Status filter
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _filters.statusFilter,
                      decoration: const InputDecoration(
                        labelText: 'Status',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: _allStatuses
                          .map(
                            (s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.isEmpty ? 'All statuses' : s),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(
                        () =>
                            _filters = _filters.copyWith(statusFilter: v ?? ''),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Sort field
                  Expanded(
                    child: DropdownButtonFormField<QuoteSortField>(
                      value: _filters.sort,
                      decoration: const InputDecoration(
                        labelText: 'Sort by',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: QuoteSortField.createdAt,
                          child: Text('Date created'),
                        ),
                        DropdownMenuItem(
                          value: QuoteSortField.quoteNumber,
                          child: Text('Quote number'),
                        ),
                        DropdownMenuItem(
                          value: QuoteSortField.status,
                          child: Text('Status'),
                        ),
                      ],
                      onChanged: (v) => setState(
                        () => _filters = _filters.copyWith(
                          sort: v ?? QuoteSortField.createdAt,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Sort direction toggle
                  IconButton.outlined(
                    tooltip: _filters.dir == QuoteSortDir.desc
                        ? 'Descending — click for ascending'
                        : 'Ascending — click for descending',
                    icon: Icon(
                      _filters.dir == QuoteSortDir.desc
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 18,
                    ),
                    onPressed: () => setState(
                      () => _filters = _filters.copyWith(
                        dir: _filters.dir == QuoteSortDir.desc
                            ? QuoteSortDir.asc
                            : QuoteSortDir.desc,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Refresh
                  IconButton.outlined(
                    tooltip: 'Refresh',
                    icon: const Icon(Icons.refresh, size: 18),
                    onPressed: () =>
                        ref.read(quoteProvider.notifier).fetchQuotes(),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // ── Quote list ────────────────────────────────────────────────────────
        Expanded(
          child: quoteState.when(
            loading: () => const AppLoader(),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Error loading quotes: $e',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ),
            data: (quotes) {
              final filtered = _applyFilters(quotes);

              if (quotes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.receipt_long_outlined,
                        size: 64,
                        color: theme.colorScheme.onSurface.withOpacity(.25),
                      ),
                      const SizedBox(height: 16),
                      Text('No quotes yet', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      const Text(
                        'Create a quote from the Quote Creation page.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
              }

              if (filtered.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No quotes match your filters.'),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final q = filtered[idx];
                  final color = _statusColor(q.status);
                  final icon = _statusIcon(q.status);

                  return Material(
                    borderRadius: BorderRadius.circular(12),
                    color: theme.cardColor,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showActionDialog(context, q),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Status indicator circle
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: color.withOpacity(.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(icon, color: color, size: 20),
                            ),
                            const SizedBox(width: 14),
                            // Quote info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        q.quoteNumber.isNotEmpty
                                            ? q.quoteNumber
                                            : '',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontFamily: 'Courier',
                                          fontSize: 13,
                                        ),
                                      ),
                                      if (q.quoteNumber.isNotEmpty)
                                        const SizedBox(width: 8),
                                      TruncatedText(
                                        q.id,
                                        maxLength: 8,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                          fontFamily: 'monospace',
                                        ),
                                        tooltipLabel: 'Full Quote UUID',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    q.applicantSnapshot['email']?.toString() ??
                                        q.applicantRef ??
                                        'No applicant info',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Status chip
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: color.withOpacity(.4),
                                ),
                              ),
                              child: Text(
                                q.status,
                                style: TextStyle(
                                  color: color,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right,
                              color: Colors.grey.shade400,
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        // ── Footer count ──────────────────────────────────────────────────────
        quoteState.maybeWhen(
          data: (quotes) {
            final filtered = _applyFilters(quotes);
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 1,
                  ),
                ),
              ),
              child: Text(
                '${filtered.length} of ${quotes.length} quote(s)',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ─── Action Dialog ───────────────────────────────────────────────────────────

class _QuoteActionDialog extends StatelessWidget {
  const _QuoteActionDialog({
    required this.quote,
    required this.statusColor,
    required this.statusIcon,
    required this.onAction,
  });

  final Quote quote;
  final Color statusColor;
  final IconData statusIcon;
  final void Function(String action) onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDraft = quote.status.toUpperCase() == 'DRAFT';
    final isTerminal = [
      'CANCELLED',
      'REJECTED',
      'ISSUED',
      'EXPIRED',
    ].contains(quote.status.toUpperCase());
    final applicant =
        quote.applicantSnapshot['email']?.toString() ??
        quote.applicantRef ??
        'Unknown';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.quoteNumber.isNotEmpty
                              ? quote.quoteNumber
                              : 'Quote',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            fontFamily: 'Courier',
                          ),
                        ),
                        const SizedBox(height: 2),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            quote.status,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    style: IconButton.styleFrom(
                      backgroundColor: theme.colorScheme.surface.withOpacity(
                        .08,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Info grid
              _InfoRow(label: 'Quote ID', value: quote.id, isId: true),
              const SizedBox(height: 8),
              _InfoRow(label: 'Applicant', value: applicant),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Created',
                value:
                    '${quote.createdAt.day}/${quote.createdAt.month}/${quote.createdAt.year}',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                label: 'Expires',
                value:
                    '${quote.expiresAt.day}/${quote.expiresAt.month}/${quote.expiresAt.year}',
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 20),
              // Copy ID button
              OutlinedButton.icon(
                onPressed: () => onAction('copy_id'),
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy Quote ID'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
              const SizedBox(height: 12),
              // Submit
              FilledButton.icon(
                onPressed: isDraft ? () => onAction('submit') : null,
                icon: const Icon(Icons.send_outlined, size: 18),
                label: Text(
                  isDraft
                      ? 'Submit for Underwriting'
                      : 'Submit (only DRAFT quotes)',
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.blue.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 8),
              // Cancel
              FilledButton.icon(
                onPressed: isTerminal ? null : () => onAction('cancel'),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel Quote'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  textStyle: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (isTerminal) ...[
                const SizedBox(height: 12),
                Text(
                  'This quote is in a terminal state and cannot be modified.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.isId = false});
  final String label;
  final String value;
  final bool isId;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: isId
              ? TruncatedText(
                  value,
                  maxLength: 20,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  tooltipLabel: 'Full ID',
                )
              : Text(value, style: const TextStyle(fontSize: 13)),
        ),
      ],
    );
  }
}
