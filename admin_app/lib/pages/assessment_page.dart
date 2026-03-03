import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/claim_provider.dart';
import '../models/claim.dart';

/// Assessment workspace: list claims, select one, submit assessment via API.
class AssessmentPage extends ConsumerStatefulWidget {
  const AssessmentPage({super.key});

  @override
  ConsumerState<AssessmentPage> createState() => _AssessmentPageState();
}

class _AssessmentPageState extends ConsumerState<AssessmentPage> {
  int _currentStep = 0;
  Claim? _selectedClaim;
  final Map<String, dynamic> _formData = {};
  bool _submitting = false;

  final List<WorkflowStep> _steps = const [
    WorkflowStep(title: 'Select Claim'),
    WorkflowStep(title: 'Review & Notes'),
    WorkflowStep(title: 'Decision'),
  ];

  @override
  Widget build(BuildContext context) {
    final claimState = ref.watch(claimProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkflowStepperWidget(
            steps: _steps.asMap().entries.map((e) {
              return e.value.copyWith(
                isActive: e.key == _currentStep,
                isCompleted: e.key < _currentStep,
              );
            }).toList(),
            currentIndex: _currentStep,
            onStepTap: (idx) => setState(() => _currentStep = idx),
          ),
          const SizedBox(height: 24),
          KeyedSubtree(
            key: ValueKey('assess_step_$_currentStep'),
            child: _buildStepContent(claimState),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(AsyncValue<List<Claim>> claimState) {
    switch (_currentStep) {
      case 0:
        return _buildSelectClaimStep(claimState);
      case 1:
        return _buildReviewStep();
      case 2:
        return _buildDecisionStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildSelectClaimStep(AsyncValue<List<Claim>> claimState) {
    return claimState.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Failed to load claims: $e', style: const TextStyle(color: Colors.red)),
        ),
      ),
      data: (claims) {
        final assessable = claims
            .where((c) =>
                c.status != 'PAID' &&
                c.status != 'REJECTED' &&
                c.status != 'CLOSED' &&
                c.status != 'WITHDRAWN')
            .toList();
        if (assessable.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No claims available for assessment.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader('Select a claim', 'Choose the claim to assess.'),
            const SizedBox(height: 16),
            ...assessable.map((claim) {
              final selected = _selectedClaim?.id == claim.id;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                color: selected ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : null,
                child: ListTile(
                  title: Text(claim.claimNumber),
                  subtitle: Text(
                    '${claim.status} · Claimed: \$${claim.claimedAmount.toStringAsFixed(2)}',
                  ),
                  trailing: selected ? const Icon(Icons.check_circle) : null,
                  onTap: () => setState(() {
                    _selectedClaim = claim;
                    _formData['assessedAmount'] = claim.claimedAmount;
                    _formData['deductibleApplied'] = 0.0;
                    _formData['netPayout'] = claim.claimedAmount;
                  }),
                ),
              );
            }),
            if (_selectedClaim != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => setState(() => _currentStep = 1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Continue to Review'),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildReviewStep() {
    if (_selectedClaim == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: TextButton(
            onPressed: () => setState(() => _currentStep = 0),
            child: const Text('Back to select a claim'),
          ),
        ),
      );
    }
    final claim = _selectedClaim!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Assessment Review', 'Evaluate evidence and add notes.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Claim: ${claim.claimNumber}', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('Claimed amount: \$${claim.claimedAmount.toStringAsFixed(2)}'),
                Text('Loss: ${claim.lossDescription}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        DynamicFormWidget(
          fields: [
            DynamicFormField(
              key: 'notes',
              label: 'Assessment Notes',
              hint: 'Summarize findings...',
              required: true,
              initialValue: _formData['notes'],
            ),
            DynamicFormField(
              key: 'riskLevel',
              label: 'Perceived Risk',
              type: DynamicFormFieldType.dropdown,
              options: const ['Low', 'Medium', 'High'],
              initialValue: _formData['riskLevel'],
            ),
          ],
          submitLabel: 'Next: Decision',
          onSubmit: (values) {
            setState(() {
              _formData.addAll(values);
              _currentStep = 2;
            });
          },
        ),
        TextButton(onPressed: () => setState(() => _currentStep = 0), child: const Text('Back')),
      ],
    );
  }

  Widget _buildDecisionStep() {
    if (_selectedClaim == null) {
      return TextButton(
        onPressed: () => setState(() => _currentStep = 0),
        child: const Text('Back to select a claim'),
      );
    }
    final claim = _selectedClaim!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader('Decision & Outcome', 'Set amounts and final outcome.'),
        const SizedBox(height: 24),
        DynamicFormWidget(
          fields: [
            DynamicFormField(
              key: 'assessedAmount',
              label: 'Assessed Amount',
              hint: 'Amount approved for coverage',
              initialValue: _formData['assessedAmount']?.toString() ?? claim.claimedAmount.toString(),
            ),
            DynamicFormField(
              key: 'deductibleApplied',
              label: 'Deductible Applied',
              hint: '0',
              initialValue: _formData['deductibleApplied']?.toString() ?? '0',
            ),
            DynamicFormField(
              key: 'netPayout',
              label: 'Net Payout',
              hint: 'Assessed minus deductible',
              initialValue: _formData['netPayout']?.toString() ?? claim.claimedAmount.toString(),
            ),
            DynamicFormField(
              key: 'reason',
              label: 'Reasoning',
              hint: 'Why this decision was made?',
              initialValue: _formData['reason'],
            ),
          ],
          submitLabel: _submitting ? 'Submitting...' : 'Submit Assessment',
          onSubmit: (values) async {
            setState(() {
              _formData.addAll(values);
              _submitting = true;
            });
            try {
              final assessedAmount = double.tryParse(values['assessedAmount']?.toString() ?? '') ?? claim.claimedAmount;
              final deductibleApplied = double.tryParse(values['deductibleApplied']?.toString() ?? '') ?? 0;
              final netPayout = double.tryParse(values['netPayout']?.toString() ?? '') ?? (assessedAmount - deductibleApplied);
              await ref.read(claimProvider.notifier).submitAssessment(claim.id, {
                'assessedAmount': assessedAmount,
                'deductibleApplied': deductibleApplied,
                'netPayout': netPayout,
                'assessmentNotes': _formData['notes']?.toString() ?? values['reason']?.toString(),
                'lineItemAssessment': <Map<String, dynamic>>[],
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Assessment submitted successfully')),
                );
                setState(() {
                  _selectedClaim = null;
                  _currentStep = 0;
                  _formData.clear();
                });
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to submit: $e')),
                );
              }
            } finally {
              if (mounted) setState(() => _submitting = false);
            }
          },
        ),
        TextButton(onPressed: () => setState(() => _currentStep = 1), child: const Text('Back')),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

extension on WorkflowStep {
  WorkflowStep copyWith({bool? isActive, bool? isCompleted}) {
    return WorkflowStep(
      title: title,
      isActive: isActive ?? this.isActive,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
