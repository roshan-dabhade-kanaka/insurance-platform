import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/policy_provider.dart';
import '../providers/quote_provider.dart';
import '../widgets/widgets.dart';
import '../models/quote.dart';
import '../core/error_handler.dart';

class PolicyIssuancePage extends ConsumerStatefulWidget {
  const PolicyIssuancePage({super.key});

  @override
  ConsumerState<PolicyIssuancePage> createState() => _PolicyIssuancePageState();
}

class _PolicyIssuancePageState extends ConsumerState<PolicyIssuancePage> {
  final _quoteIdController = TextEditingController();
  Quote? _selectedQuote;

  @override
  void dispose() {
    _quoteIdController.dispose();
    super.dispose();
  }

  void _onQuoteSelected(Quote quote) {
    setState(() {
      _selectedQuote = quote;
      _quoteIdController.text =
          quote.quoteNumber; // Use Quote Number for user-friendly display
    });
  }

  @override
  Widget build(BuildContext context) {
    final policyState = ref.watch(policyProvider);
    final quoteState = ref.watch(quoteProvider);
    final theme = Theme.of(context);

    // Filter for approved quotes
    final approvedQuotes = quoteState.maybeWhen(
      data: (quotes) =>
          quotes.where((q) => q.status.toUpperCase() == 'APPROVED').toList(),
      orElse: () => <Quote>[],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Select an approved quote from the list below. Both Quote Number (e.g., QT-202) and Technical ID (UUID) are supported.',
          ),
          const SizedBox(height: 24),

          // Row for List and Manual Input
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left side: Approved Quotes Table
              Expanded(
                flex: 3,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Approved Quotes',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(Icons.refresh, size: 20),
                              onPressed: () => ref
                                  .read(quoteProvider.notifier)
                                  .fetchQuotes(),
                            ),
                          ],
                        ),
                        const Divider(),
                        if (quoteState.isLoading)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (approvedQuotes.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(40),
                            child: Center(
                              child: Text(
                                'No approved quotes found.\nQuotes must be approved by an underwriter first.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: approvedQuotes.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final quote = approvedQuotes[index];
                              final isSelected = _selectedQuote?.id == quote.id;

                              return ListTile(
                                selected: isSelected,
                                selectedTileColor: theme
                                    .colorScheme
                                    .primaryContainer
                                    .withOpacity(0.3),
                                leading: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.description,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                ),
                                title: Row(
                                  children: [
                                    Text(
                                      quote.quoteNumber,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    if (!quote.hasPremium) ...[
                                      const SizedBox(width: 8),
                                      const Tooltip(
                                        message: 'No premium calculated yet!',
                                        child: Icon(
                                          Icons.warning_amber_rounded,
                                          color: Colors.orange,
                                          size: 16,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    TruncatedText(
                                      quote.id,
                                      maxLength: 8,
                                      tooltipLabel: 'Full Quote UUID',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                    Text(
                                      'Applicant: ${quote.applicantSnapshot['email'] ?? quote.applicantRef ?? "Unknown"}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                                isThreeLine: true,
                                trailing: isSelected
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Colors.blue,
                                      )
                                    : const Icon(Icons.chevron_right),
                                onTap: () => _onQuoteSelected(quote),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Right side: Decision Card
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Issuance Details',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 32),
                            TextField(
                              controller: _quoteIdController,
                              style: const TextStyle(
                                fontSize: 13,
                                fontFamily: 'monospace',
                              ),
                              decoration: const InputDecoration(
                                labelText: 'Quote Reference',
                                prefixIcon: Icon(
                                  Icons.confirmation_number_outlined,
                                ),
                                hintText:
                                    'Select a quote or enter Quote # or UUID',
                              ),
                              onChanged: (val) {
                                if (_selectedQuote?.quoteNumber != val &&
                                    _selectedQuote?.id != val) {
                                  setState(() => _selectedQuote = null);
                                }
                              },
                            ),
                            const SizedBox(height: 20),
                            if (_selectedQuote != null) ...[
                              _DetailRow(
                                label: 'Quote #',
                                value: _selectedQuote!.quoteNumber,
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: 'Technical ID',
                                value: _selectedQuote!.id,
                                isTechnical: true,
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: 'Applicant',
                                value:
                                    _selectedQuote!
                                        .applicantSnapshot['firstName']
                                        ?.toString() ??
                                    "N/A",
                              ),
                              const SizedBox(height: 8),
                              _DetailRow(
                                label: 'Status',
                                value: _selectedQuote!.status,
                                color: Colors.green,
                              ),
                              const SizedBox(height: 12),
                              if (!_selectedQuote!.hasPremium)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.orange.shade200,
                                    ),
                                  ),
                                  child: const Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber_rounded,
                                        color: Colors.orange,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Recommendation: Calculate premium first to avoid issuance errors.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.brown,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 24),
                            ],
                            if (policyState.isLoading)
                              const AppLoader()
                            else
                              FilledButton.icon(
                                onPressed: _quoteIdController.text.isEmpty
                                    ? null
                                    : () async {
                                        try {
                                          await ref
                                              .read(policyProvider.notifier)
                                              .issuePolicy(
                                                _quoteIdController.text.trim(),
                                                {},
                                              );
                                          if (context.mounted) {
                                            ResponseHandler.showSuccess(
                                              context,
                                              'Policy issued successfully',
                                            );
                                            _quoteIdController.clear();
                                            setState(
                                              () => _selectedQuote = null,
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ResponseHandler.showError(
                                              context,
                                              e,
                                              fallback: 'Issuance failed',
                                            );
                                          }
                                        }
                                      },
                                icon: const Icon(Icons.rocket_launch_outlined),
                                label: const Text('Generate & Issue Policy'),
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.all(16),
                                  backgroundColor: Colors.blue.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const InfoBox(
                      message:
                          'Policy generation will trigger document creation and temporal workflow initiation.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  final bool isTechnical;

  const _DetailRow({
    required this.label,
    required this.value,
    this.color,
    this.isTechnical = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
        isTechnical
            ? TruncatedText(
                value,
                maxLength: 12,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                  fontFamily: 'monospace',
                ),
                tooltipLabel: 'Full UUID',
              )
            : Text(
                value,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
      ],
    );
  }
}
