import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/role_access.dart';
import '../providers/underwriting_provider.dart';
import '../providers/quote_provider.dart';
import '../models/quote.dart';
import '../widgets/widgets.dart';
import 'package:collection/collection.dart';

class UnderwritingDecisionPage extends ConsumerWidget {
  const UnderwritingDecisionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uwState = ref.watch(underwritingProvider);
    final quoteState = ref.watch(quoteProvider);
    final user = ref.watch(authNotifierProvider).user;
    final canApprove =
        user != null && canPerform(AppAction.underwritingApprove, user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Underwriters review submitted quotes here. Approve to issue the policy or reject to return the quote. '
                'A quote must be in SUBMITTED status to appear for review.',
          ),
          const SizedBox(height: 24),

          // ── Submitted Quotes (quick reference) ─────────────────────────────
          quoteState.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (quotes) {
              final submitted = quotes
                  .where((q) => q.status.toUpperCase() == 'SUBMITTED')
                  .toList();
              if (submitted.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Submitted Quotes (${submitted.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...submitted.map(
                    (q) => _SubmittedQuoteCard(
                      quote: q,
                      canApprove: canApprove,
                      userId: user?.id ?? 'admin',
                      ref: ref,
                    ),
                  ),
                  const Divider(height: 40),
                ],
              );
            },
          ),

          // ── Formal UW Cases ─────────────────────────────────────────────────
          Text(
            'Underwriting Cases',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          uwState.when(
            data: (cases) => cases.isEmpty
                ? Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Column(
                          children: [
                            const Icon(
                              Icons.inbox_outlined,
                              size: 48,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No pending underwriting cases.',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Cases are created automatically when a Temporal workflow processes a submitted quote.',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : Column(
                    children: cases.map((uwCase) {
                      final quote = quoteState.asData?.value.firstWhereOrNull(
                        (q) => q.id == uwCase.quoteId,
                      );

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: ApprovalDecisionPanel(
                          title:
                              'UW Case — ${quote?.quoteNumber ?? (uwCase.quoteId.length >= 8 ? uwCase.quoteId.substring(0, 8) : uwCase.quoteId)}',
                          subtitle:
                              'Status: ${uwCase.status} • Level: ${uwCase.currentApprovalLevel}',
                          detailWidget: Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: _InfoTile(
                                        label: 'Applicant',
                                        value: quote?.applicantRef ?? 'Unknown',
                                        icon: Icons.person_outline,
                                      ),
                                    ),
                                    Expanded(
                                      child: _InfoTile(
                                        label: 'Risk Info',
                                        value:
                                            quote != null &&
                                                (quote.applicantSnapshot['smoker'] ==
                                                        true ||
                                                    quote.applicantSnapshot['smoker'] ==
                                                        'true')
                                            ? 'Smoker'
                                            : 'Non-Smoker',
                                        icon: Icons.health_and_safety_outlined,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    uwCase.requiresSeniorReview
                                        ? '⚠️ Requires Senior Underwriter Approval'
                                        : 'Standard Review Process',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: uwCase.requiresSeniorReview
                                          ? Colors.orange.shade800
                                          : Theme.of(
                                              context,
                                            ).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          onApprove: canApprove
                              ? () async {
                                  await _decideCase(
                                    context: context,
                                    ref: ref,
                                    uwCaseId: uwCase.id,
                                    userId: user.id,
                                    decision: 'APPROVE',
                                    approvalLevel: uwCase.currentApprovalLevel,
                                    successMsg: 'Case approved!',
                                  );
                                }
                              : null,
                          onReject: canApprove
                              ? () async {
                                  await _decideCase(
                                    context: context,
                                    ref: ref,
                                    uwCaseId: uwCase.id,
                                    userId: user.id,
                                    decision: 'REJECT',
                                    approvalLevel: uwCase.currentApprovalLevel,
                                    successMsg: 'Case rejected.',
                                  );
                                }
                              : null,
                          approveLabel: 'Approve',
                          rejectLabel: 'Reject',
                        ),
                      );
                    }).toList(),
                  ),
            loading: () => const AppLoader(),
            error: (e, _) => Center(
              child: Text(
                'Error loading cases: $e',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _decideCase({
    required BuildContext context,
    required WidgetRef ref,
    required String uwCaseId,
    required String userId,
    required String decision,
    required int approvalLevel,
    required String successMsg,
  }) async {
    try {
      final lockResult = await ref
          .read(underwritingProvider.notifier)
          .acquireLock(uwCaseId, userId);
      final lockToken =
          lockResult['lockToken']?.toString() ??
          lockResult['token']?.toString();
      if (lockToken == null || lockToken.isEmpty) {
        throw Exception(
          'Could not acquire lock — case may be locked by another user.',
        );
      }

      final decisionData = {
        'decidedBy': userId,
        'decision': decision,
        'approvalLevel': approvalLevel,
        'lockToken': lockToken,
      };

      if (decision == 'APPROVE') {
        await ref
            .read(underwritingProvider.notifier)
            .approveCase(uwCaseId, decisionData);
      } else {
        await ref
            .read(underwritingProvider.notifier)
            .rejectCase(uwCaseId, decisionData);
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMsg)));
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
  }
}

/// Shows a submitted quote that can be directly approved/rejected via the
/// quote status endpoint (for when Temporal hasn't created a formal UW case yet).
class _SubmittedQuoteCard extends StatelessWidget {
  const _SubmittedQuoteCard({
    required this.quote,
    required this.canApprove,
    required this.userId,
    required this.ref,
  });

  final Quote quote;
  final bool canApprove;
  final String userId;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.assignment_turned_in_outlined,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    quote.quoteNumber.isNotEmpty ? quote.quoteNumber : quote.id,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Courier',
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'SUBMITTED',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Applicant: ${quote.applicantSnapshot['email'] ?? quote.applicantRef ?? '-'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            Text(
              'Quote ID: ${quote.id}',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
            if (canApprove) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await ref
                            .read(quoteProvider.notifier)
                            .submitQuoteDecision(quote.id, 'APPROVED', userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Quote approved — policy issuance ready.',
                              ),
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
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await ref
                            .read(quoteProvider.notifier)
                            .submitQuoteDecision(quote.id, 'REJECTED', userId);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Quote rejected.')),
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
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ],
    );
  }
}
