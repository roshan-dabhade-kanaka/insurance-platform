import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/policy_provider.dart';
import '../widgets/widgets.dart';

class PolicyLifecyclePage extends ConsumerStatefulWidget {
  const PolicyLifecyclePage({super.key});

  @override
  ConsumerState<PolicyLifecyclePage> createState() =>
      _PolicyLifecyclePageState();
}

class _PolicyLifecyclePageState extends ConsumerState<PolicyLifecyclePage> {
  @override
  void initState() {
    super.initState();
    // Fetch policies when the page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(policyProvider.notifier).fetchPolicies();
    });
  }

  @override
  Widget build(BuildContext context) {
    final policyState = ref.watch(policyProvider);
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'View all issued policies. Policies that are actively billed and within their coverage dates are shown here.',
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(
                        'Active Policies',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () =>
                            ref.read(policyProvider.notifier).fetchPolicies(),
                      ),
                    ],
                  ),
                  const Divider(),
                  if (policyState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (policyState.hasError)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'Error loading policies. Please try again.',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    )
                  else if (policyState.value == null ||
                      policyState.value!.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(
                        child: Text(
                          'No active policies found.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: policyState.value!.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final policy = policyState.value![index];
                        final formatter = NumberFormat.currency(
                          symbol: '₹',
                          locale: 'en_IN',
                        );
                        final dateFormatter = DateFormat('MMM dd, yyyy');

                        return ExpansionTile(
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.shield,
                              color: Colors.green,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            policy.policyNumber,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                          subtitle: Text('Status: ${policy.status}'),
                          childrenPadding: const EdgeInsets.all(16),
                          expandedCrossAxisAlignment:
                              CrossAxisAlignment.stretch,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _DetailColumn(
                                    label: 'Total Premium',
                                    value: formatter.format(
                                      policy.totalPremium,
                                    ),
                                  ),
                                  _DetailColumn(
                                    label: 'Inception Date',
                                    value: dateFormatter.format(
                                      policy.inceptionDate,
                                    ),
                                  ),
                                  _DetailColumn(
                                    label: 'Expiry Date',
                                    value: dateFormatter.format(
                                      policy.expiryDate,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (policy.status == 'PENDING_ISSUANCE')
                                  FilledButton.icon(
                                    onPressed: () async {
                                      try {
                                        await ref
                                            .read(policyProvider.notifier)
                                            .activatePolicy(policy.id);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Policy activated successfully',
                                              ),
                                              backgroundColor: Colors.green,
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
                                                'Failed to activate: $e',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                      }
                                    },
                                    icon: const Icon(Icons.bolt, size: 16),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.green,
                                    ),
                                    label: const Text('Activate Policy'),
                                  ),
                                const SizedBox(width: 12),
                                TextButton.icon(
                                  onPressed: () {},
                                  icon: const Icon(
                                    Icons.remove_red_eye_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('View Full JSON Dump'),
                                ),
                              ],
                            ),
                          ],
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

class _DetailColumn extends StatelessWidget {
  final String label;
  final String value;

  const _DetailColumn({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ],
    );
  }
}
