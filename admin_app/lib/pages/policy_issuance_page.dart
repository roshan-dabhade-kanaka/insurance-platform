import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/policy_provider.dart';

class PolicyIssuancePage extends ConsumerStatefulWidget {
  const PolicyIssuancePage({super.key});

  @override
  ConsumerState<PolicyIssuancePage> createState() => _PolicyIssuancePageState();
}

class _PolicyIssuancePageState extends ConsumerState<PolicyIssuancePage> {
  final _quoteIdController = TextEditingController();

  @override
  void dispose() {
    _quoteIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final policyState = ref.watch(policyProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Issue Policy',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Enter an approved Quote ID to generate the official policy document and activate coverage.',
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _quoteIdController,
                    decoration: const InputDecoration(
                      labelText: 'Approved Quote ID',
                      hintText: 'e.g. 550e8400-e29b-41d4-a716-446655440000',
                      prefixIcon: Icon(Icons.assignment_turned_in_outlined),
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (policyState.isLoading)
                    const Center(child: CircularProgressIndicator())
                  else
                    FilledButton.icon(
                      onPressed: () async {
                        if (_quoteIdController.text.isEmpty) return;
                        try {
                          await ref
                              .read(policyProvider.notifier)
                              .issuePolicy(_quoteIdController.text.trim());
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Policy issued successfully!'),
                              ),
                            );
                            _quoteIdController.clear();
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Issuance failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.description_outlined),
                      label: const Text('Generate & Issue Policy'),
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
