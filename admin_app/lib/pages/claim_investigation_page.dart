import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/claim_provider.dart';

import '../auth/auth_provider.dart';
import '../auth/auth_model.dart';

class ClaimInvestigationPage extends ConsumerWidget {
  const ClaimInvestigationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claimState = ref.watch(claimProvider);
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
          const InfoBox(
            message:
                'Review pending claims and initiate formal investigations where required by policy rules.',
          ),
          const SizedBox(height: 24),
          claimState.when(
            loading: () => const AppLoader(),
            error: (err, stack) => Center(child: Text('Error: $err')),
            data: (claims) {
              final pendingClaims = claims
                  .where(
                    (c) =>
                        c.status == 'SUBMITTED' ||
                        c.status == 'VALIDATED' ||
                        c.status == 'UNDER_INVESTIGATION',
                  )
                  .toList();

              if (pendingClaims.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No pending investigations.')),
                  ),
                );
              }

              return Column(
                children: pendingClaims.map((claim) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Claim: ${claim.claimNumber}',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text('Status: ${claim.status}'),
                          const SizedBox(height: 20),
                          ApprovalDecisionPanel(
                            title: 'Assessment Requisite',
                            subtitle:
                                'Claimed: ₹${claim.claimedAmount.toStringAsFixed(2)}',
                            onApprove: () async {
                              try {
                                await ref
                                    .read(claimProvider.notifier)
                                    .investigateClaim(claim.id, {
                                      'investigatorId': userId ?? 'unknown',
                                      'notes':
                                          'Manual investigation started via Admin UI.',
                                    });
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Investigation initiated.'),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Failed: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            onReject: () {},
                            approveLabel: 'Initiate Investigation',
                            rejectLabel: 'Dismiss',
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
