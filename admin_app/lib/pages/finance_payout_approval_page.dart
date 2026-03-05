import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/role_access.dart';
import '../providers/finance_provider.dart';
import '../providers/admin_providers.dart';
import '../theme/app_theme.dart';
import '../widgets/widgets.dart';

class FinancePayoutApprovalPage extends ConsumerWidget {
  const FinancePayoutApprovalPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeState = ref.watch(financeProvider);
    final processedAsync = ref.watch(processedTodayProvider);
    final theme = Theme.of(context);
    final user = ref.watch(authNotifierProvider).user;
    final canApprovePayout =
        user != null && canPerform(AppAction.financePayoutApproval, user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Approve or hold pending disbursements. Approved payouts will be processed by the finance integration service.',
          ),
          const SizedBox(height: 24),
          if (financeState.isLoading) const AppLoader(),
          Row(
            children: [
              // ── Pending disbursement card (live from API) ──────────────
              Expanded(
                child: Card(
                  color: AppTheme.primaryColor,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PENDING DISBURSEMENT',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          financeState.when(
                            data: (list) =>
                                '₹${list.fold<double>(0, (s, i) => s + i.totalAmount).toStringAsFixed(0)}',
                            loading: () => '...',
                            error: (_, _e) => 'Error',
                          ),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          financeState.when(
                            data: (list) => '${list.length} Payments ready',
                            loading: () => 'Loading...',
                            error: (_, _e) => 'Error loading',
                          ),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // ── Processed today card (live from GET /payouts/processed-today) ──
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PROCESSED TODAY',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        processedAsync.when(
                          loading: () =>
                              const SizedBox(height: 28, child: AppLoader()),
                          error: (_, _e) => Text(
                            '—',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          data: (stats) => Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                stats != null
                                    ? '₹${stats.amount.toStringAsFixed(0)}'
                                    : '—',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                stats != null
                                    ? '${stats.count} Successful payouts'
                                    : 'No data',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ── Payout list ────────────────────────────────────────────────
          financeState.when(
            loading: () => const AppLoader(),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (payouts) {
              if (payouts.isEmpty) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No pending payout approvals.')),
                  ),
                );
              }
              return Column(
                children: payouts.map((payout) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: ApprovalDecisionPanel(
                        title: 'Payout Request: ${payout.id.substring(0, 8)}',
                        subtitle:
                            'Amount: ₹${payout.totalAmount.toStringAsFixed(2)} • Status: ${payout.status}',
                        onApprove: canApprovePayout
                            ? () async {
                                try {
                                  await ref
                                      .read(financeProvider.notifier)
                                      .approvePayout(payout.claimId, {
                                        'approverId': user.id,
                                        'decision': 'APPROVE',
                                        'approvedAmount': payout.totalAmount,
                                        'notes': 'Approved via Finance UI.',
                                      });
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Payout approved! Disbursement initiated.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Approval failed: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        onReject: canApprovePayout
                            ? () async {
                                try {
                                  await ref
                                      .read(financeProvider.notifier)
                                      .processPayment(
                                        payout.id,
                                        payout.claimId,
                                        {
                                          'decision': 'HOLD',
                                          'approverId': user.id,
                                        },
                                      );
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Payout put on hold.'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to hold: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              }
                            : null,
                        approveLabel: 'Approve Payout',
                        rejectLabel: 'Hold',
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
