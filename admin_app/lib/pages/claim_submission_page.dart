import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/claim_provider.dart';
import '../auth/auth_provider.dart';
import '../auth/auth_model.dart';

class ClaimSubmissionPage extends ConsumerWidget {
  const ClaimSubmissionPage({super.key});

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
                'Submit a new claim for an existing policy. Provide the policy details, loss information, and requested amount.',
          ),
          const SizedBox(height: 24),
          if (claimState.isLoading)
            const AppLoader()
          else
            DynamicFormWidget(
              fields: const [
                DynamicFormField(
                  key: 'policyId',
                  label: 'Policy ID',
                  required: true,
                ),
                DynamicFormField(
                  key: 'policyCoverageId',
                  label: 'Coverage ID',
                  required: true,
                ),
                DynamicFormField(
                  key: 'amount',
                  label: 'Claimed Amount',
                  type: DynamicFormFieldType.number,
                  required: true,
                ),
                DynamicFormField(
                  key: 'lossDate',
                  label: 'Loss Date',
                  type: DynamicFormFieldType.date,
                  required: true,
                  hint: 'YYYY-MM-DD',
                ),
                DynamicFormField(
                  key: 'description',
                  label: 'Incident Description',
                  required: true,
                ),
              ],
              submitLabel: 'Submit Claim',
              onSubmit: (values) async {
                try {
                  await ref.read(claimProvider.notifier).submitClaim({
                    'policyId': values['policyId'],
                    'policyCoverageId': values['policyCoverageId'],
                    'claimedAmount': double.parse(values['amount']),
                    'lossDate': values['lossDate'],
                    'lossDescription': values['description'],
                    'claimantData': {}, // Placeholder for extra metadata
                    'submittedBy': userId ?? 'unknown',
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Claim submitted successfully!'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to submit claim: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
        ],
      ),
    );
  }
}
