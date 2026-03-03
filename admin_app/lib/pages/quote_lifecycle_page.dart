import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/quote_provider.dart';

class QuoteLifecyclePage extends ConsumerStatefulWidget {
  const QuoteLifecyclePage({super.key});

  @override
  ConsumerState<QuoteLifecyclePage> createState() => _QuoteLifecyclePageState();
}

class _QuoteLifecyclePageState extends ConsumerState<QuoteLifecyclePage> {
  final _idController = TextEditingController();

  @override
  void dispose() {
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final quoteState = ref.watch(quoteProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Quote Lifecycle & Submission',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _idController,
                      decoration: const InputDecoration(
                        labelText: 'Quote ID',
                        hintText: 'Enter ID to track or submit...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  FilledButton.icon(
                    onPressed: () async {
                      if (_idController.text.isEmpty) return;
                      try {
                        await ref
                            .read(quoteProvider.notifier)
                            .fetchQuoteDetails(_idController.text.trim());
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Not found: $e'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('Track'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          if (quoteState.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            // In a real app, we'd check if we have the specific quote details in state
            // For now, we'll show a sample submission button for the entered ID
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Actions for ${_idController.text.isEmpty ? "..." : _idController.text}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Once a quote is in DRAFT state, it must be submitted for underwriting review.',
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        FilledButton.icon(
                          onPressed: _idController.text.isEmpty
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(quoteProvider.notifier)
                                        .submitQuote(_idController.text.trim());
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Quote submitted for underwriting!',
                                          ),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Submission failed: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Submit for Underwriting'),
                        ),
                        const SizedBox(width: 16),
                        OutlinedButton.icon(
                          onPressed: _idController.text.isEmpty
                              ? null
                              : () async {
                                  try {
                                    await ref
                                        .read(quoteProvider.notifier)
                                        .cancelQuote(_idController.text.trim());
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Quote cancelled.'),
                                        ),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Cancellation failed: $e',
                                          ),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('Cancel Quote'),
                        ),
                      ],
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
