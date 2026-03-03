import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/fraud_provider.dart';

import '../auth/auth_provider.dart';
import '../auth/auth_model.dart';

class FraudReviewPage extends ConsumerWidget {
  const FraudReviewPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fraudState = ref.watch(fraudProvider);
    final authNotifier = ref.watch(authNotifierProvider);
    final authState = authNotifier.state;

    String? userId;
    if (authState is AuthAuthenticated) {
      userId = authState.user.id;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          fraudState.when(
            loading: () => const LinearProgressIndicator(),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (claims) {
              if (claims.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(
                      child: Text('No claims flagged for fraud review.'),
                    ),
                  ),
                );
              }

              return Column(
                children: claims.map((claim) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_outlined,
                                color: Theme.of(context).colorScheme.error,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Flagged Claim: ${claim.claimNumber}',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('Requested Amount: ₹${claim.claimedAmount}'),
                          const SizedBox(height: 16),
                          ApprovalDecisionPanel(
                            title: 'Review Triggers',
                            subtitle:
                                'Reason: Escalated for Manual Verification',
                            onApprove: () async {
                              try {
                                await ref
                                    .read(fraudProvider.notifier)
                                    .submitReview(claim.id, {
                                      'reviewedBy': userId ?? 'unknown',
                                      'decision': 'CLEAR',
                                      'overallScore': 0.1,
                                    });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Claim cleared of fraud!'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Action failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            onReject: () async {
                              try {
                                await ref
                                    .read(fraudProvider.notifier)
                                    .submitReview(claim.id, {
                                      'reviewedBy': userId ?? 'unknown',
                                      'decision': 'ESCALATE',
                                      'overallScore': 0.95,
                                    });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Claim escalated for further investigation!',
                                      ),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Action failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            approveLabel: 'Clear',
                            rejectLabel: 'Escalate',
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
