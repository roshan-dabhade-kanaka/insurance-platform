import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../auth/auth_provider.dart';
import '../core/constants.dart';
import '../widgets/widgets.dart';

/// Risk profiling form with stepper (Personal > Occupation > Health > Review).
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
    WorkflowStep(title: 'History'),
    WorkflowStep(title: 'Review'),
  ];

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _buildResultView();
    return _buildStepView();
  }

  Widget _buildStepView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Provide accurate applicant details across Personal, Occupation, and Health sections. The system will score and profile the risk for pricing.',
          ),
          const SizedBox(height: 24),
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
        return _buildHistoryStep();
      case 4:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildPersonalStep() {
    return DynamicFormWidget(
      fields: [
        DynamicFormField(
          key: 'fullName',
          label: 'Full Name',
          hint: 'John Doe',
          required: true,
          initialValue: _formData['fullName'],
        ),
        DynamicFormField(
          key: 'age',
          label: 'Age',
          type: DynamicFormFieldType.number,
          required: true,
          initialValue: _formData['age'],
        ),
        DynamicFormField(
          key: 'gender',
          label: 'Gender',
          type: DynamicFormFieldType.dropdown,
          options: const ['Male', 'Female', 'Other'],
          initialValue: _formData['gender'],
        ),
      ],
      submitLabel: 'Next: Occupation →',
      onSubmit: (values) {
        setState(() {
          _formData.addAll(values);
          _currentStep = 1;
        });
      },
    );
  }

  Widget _buildOccupationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          submitLabel: 'Next: Health →',
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
          submitLabel: 'Next: Review →',
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

  Widget _buildHistoryStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DynamicFormWidget(
          fields: [
            DynamicFormField(
              key: 'vehicleHistory',
              label: 'Vehicle History',
              type: DynamicFormFieldType.dropdown,
              options: const ['Clean', 'Minor Accidents', 'Major Accidents'],
              initialValue: _formData['vehicleHistory'] ?? 'Clean',
            ),
            DynamicFormField(
              key: 'propertyDetails',
              label: 'Property Details (optional)',
              hint: 'Type of property, alarms installed etc.',
              initialValue: _formData['propertyDetails'],
            ),
            DynamicFormField(
              key: 'previousClaims',
              label: 'Number of Previous Claims',
              type: DynamicFormFieldType.number,
              hint: '0',
              required: true,
              initialValue: _formData['previousClaims']?.toString() ?? '0',
            ),
          ],
          submitLabel: 'Next: Review →',
          onSubmit: (values) {
            setState(() {
              _formData.addAll(values);
              _currentStep = 4;
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review your details',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Divider(height: 24),
                ..._formData.entries.map((e) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          e.key,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(e.value.toString()),
                      ],
                    ),
                  );
                }),
              ],
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

  Widget _buildBackButton() {
    return TextButton.icon(
      onPressed: () => setState(() => _currentStep--),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Back'),
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
        builder: (context) => const AppLoader(),
      );

      final res = await client.post(
        'risk/assess',
        data: _formData,
        queryParameters: {'tenantId': tenantId},
      );

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
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
            'Risk Score: ${_results?['totalScore'] ?? '750'}/1000',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Category: ${_results?['riskBand'] ?? 'STANDARD'}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.blue.shade700,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Premium Adjustment: ${_results?['loadingPercentage'] ?? '0.00'}%',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color:
                  (_results?['loadingPercentage'] ?? '0').toString().startsWith(
                    '-',
                  )
                  ? Colors.green.shade700
                  : Colors.orange.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 48),
          FilledButton(
            onPressed: () => setState(() {
              _submitted = false;
              _currentStep = 0;
              _formData.clear();
              _results = null;
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
