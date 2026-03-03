import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../auth/auth_provider.dart';
import '../core/constants.dart';
import '../widgets/widgets.dart';

/// Risk profiling form with stepper (from risk_profiling_form).
class RiskProfilingPage extends ConsumerStatefulWidget {
  const RiskProfilingPage({super.key});

  @override
  ConsumerState<RiskProfilingPage> createState() => _RiskProfilingPageState();
}

class _RiskProfilingPageState extends ConsumerState<RiskProfilingPage> {
  bool _submitted = false;
  int _currentStep = 0;
  final Map<String, dynamic> _formData = {};
  Map<String, dynamic>? _results;

  final List<WorkflowStep> _steps = const [
    WorkflowStep(title: 'Personal'),
    WorkflowStep(title: 'Occupation'),
    WorkflowStep(title: 'Health'),
    WorkflowStep(title: 'Review'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_submitted) {
      return _buildResultView();
    }

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
          ),
          const SizedBox(height: 32),
          KeyedSubtree(
            key: ValueKey('step_$_currentStep'),
            child: _buildCurrentStepContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildPersonalStep();
      case 1:
        return _buildOccupationStep();
      case 2:
        return _buildHealthStep();
      case 3:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          'Personal Information',
          'Provide accurate details for policy pricing.',
        ),
        const SizedBox(height: 24),
        DynamicFormWidget(
          fields: [
            DynamicFormField(
              key: 'fullName',
              label: 'Full Name',
              hint: 'John Doe',
              required: true,
              initialValue: _formData['fullName'],
            ),
            DynamicFormField(
              key: 'dob',
              label: 'Date of Birth',
              type: DynamicFormFieldType.date,
              required: true,
              initialValue: _formData['dob'],
            ),
            DynamicFormField(
              key: 'gender',
              label: 'Gender',
              type: DynamicFormFieldType.dropdown,
              options: const ['Male', 'Female', 'Other'],
              initialValue: _formData['gender'],
            ),
          ],
          submitLabel: 'Next: Occupation',
          onSubmit: (values) {
            setState(() {
              _formData.addAll(values);
              _currentStep = 1;
            });
          },
        ),
      ],
    );
  }

  Widget _buildOccupationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          'Occupation Details',
          'Tell us about your work environment.',
        ),
        const SizedBox(height: 24),
        DynamicFormWidget(
          fields: [
            DynamicFormField(
              key: 'occupation',
              label: 'Current Occupation',
              hint: 'Software Engineer',
              required: true,
              initialValue: _formData['occupation'],
            ),
            DynamicFormField(
              key: 'category',
              label: 'Risk Category',
              type: DynamicFormFieldType.radio,
              options: const ['Standard Office', 'Manual', 'High Risk'],
              initialValue: _formData['category'],
            ),
            DynamicFormField(
              key: 'industry',
              label: 'Industry',
              type: DynamicFormFieldType.dropdown,
              options: const [
                'Technology',
                'Healthcare',
                'Construction',
                'Finance',
              ],
              initialValue: _formData['industry'],
            ),
          ],
          submitLabel: 'Next: Health',
          onSubmit: (values) {
            setState(() {
              _formData.addAll(values);
              _currentStep = 2;
            });
          },
        ),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildHealthStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          'Health Assessment',
          'Basic health questions for risk evaluation.',
        ),
        const SizedBox(height: 24),
        DynamicFormWidget(
          fields: [
            const DynamicFormField(
              key: 'smoker',
              label: 'Do you smoke?',
              type: DynamicFormFieldType.checkbox,
            ),
            DynamicFormField(
              key: 'bmi',
              label: 'Approximate BMI',
              type: DynamicFormFieldType.number,
              hint: 'e.g. 24',
              initialValue: _formData['bmi'],
            ),
            const DynamicFormField(
              key: 'existingConditions',
              label: 'Any chronic conditions?',
              type: DynamicFormFieldType.checkbox,
            ),
          ],
          submitLabel: 'Next: Review',
          onSubmit: (values) {
            setState(() {
              _formData.addAll(values);
              _currentStep = 3;
            });
          },
        ),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(
          'Review & Submit',
          'Check your details before assessment.',
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: _formData.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        e.key.toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(e.value.toString()),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitAssessment,
          child: const Text('Submit for Assessment'),
        ),
        _buildBackButton(),
      ],
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
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

  Widget _buildBackButton() {
    return TextButton(
      onPressed: () => setState(() => _currentStep--),
      child: const Text('Back'),
    );
  }

  Future<void> _submitAssessment() async {
    try {
      final client = ref.read(apiClientProvider);
      final auth = ref.read(authNotifierProvider);
      final tenantId = auth.user?.tenantId ?? ApiConstants.defaultTenantId;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final res = await client.post(
        '/risk/assess',
        data: _formData,
        queryParameters: {'tenantId': tenantId},
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Close loader
        if (res.statusCode == 201 || res.statusCode == 200) {
          setState(() {
            _submitted = true;
            _results = res.data;
          });
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${res.statusCode}')));
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildResultView() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
          const SizedBox(height: 24),
          Text(
            'Assessment Complete',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 12),
          Text(
            'Risk Score: ${_results?['score'] ?? '75/100'}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Status: ${_results?['status'] ?? 'ELIGIBLE'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () => setState(() {
              _submitted = false;
              _currentStep = 0;
              _formData.clear();
            }),
            child: const Text('Restart Assessment'),
          ),
        ],
      ),
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
