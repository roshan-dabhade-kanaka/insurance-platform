import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../auth/role_access.dart';
import '../providers/underwriting_provider.dart';
import '../widgets/widgets.dart';

class UnderwritingDecisionPage extends ConsumerWidget {
  const UnderwritingDecisionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uwState = ref.watch(underwritingProvider);
    final user = ref.watch(authNotifierProvider).user;
    final canApprove =
        user != null && canPerform(AppAction.underwritingApprove, user);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (uwState.isLoading) const LinearProgressIndicator(),

          uwState.when(
            data: (cases) => cases.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(48),
                      child: Text('No pending underwriting cases.'),
                    ),
                  )
                : Column(
                    children: cases
                        .map(
                          (uwCase) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: ApprovalDecisionPanel(
                              title:
                                  'Quote #${uwCase.quoteId.length >= 8 ? uwCase.quoteId.substring(0, 8) : uwCase.quoteId}',
                              subtitle:
                                  'Status: ${uwCase.status} • Level: ${uwCase.currentApprovalLevel}',
                              detailWidget: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  uwCase.requiresSeniorReview
                                      ? 'Requires Senior Underwriter Approval'
                                      : 'Standard Review',
                                ),
                              ),
                              onApprove: canApprove
                                  ? () async {
                                      // Acquire lock first, then approve.
                                      await _decideCase(
                                        context: context,
                                        ref: ref,
                                        uwCaseId: uwCase.id,
                                        userId: user.id,
                                        decision: 'APPROVE',
                                        approvalLevel:
                                            uwCase.currentApprovalLevel,
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
                                        approvalLevel:
                                            uwCase.currentApprovalLevel,
                                        successMsg: 'Case rejected.',
                                      );
                                    }
                                  : null,
                              approveLabel: 'Approve',
                              rejectLabel: 'Reject',
                            ),
                          ),
                        )
                        .toList(),
                  ),
            loading: () => const SizedBox.shrink(),
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

  /// Acquires lock, then approves or rejects. Shows snackbars on outcome.
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
      // Step 1: acquire a concurrency lock to prevent conflicting decisions.
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

      // Step 2: submit decision with the real lock token.
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
