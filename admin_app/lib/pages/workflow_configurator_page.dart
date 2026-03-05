import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../core/api_client.dart';

/// Approval workflow configurator (from approval_workflow_configurator).
class WorkflowConfiguratorPage extends ConsumerStatefulWidget {
  const WorkflowConfiguratorPage({super.key});

  @override
  ConsumerState<WorkflowConfiguratorPage> createState() =>
      _WorkflowConfiguratorPageState();
}

class _WorkflowConfiguratorPageState
    extends ConsumerState<WorkflowConfiguratorPage> {
  int _currentStep = 0;
  final List<WorkflowStep> _steps = const [
    WorkflowStep(title: 'Hierarchy', isActive: true),
    WorkflowStep(title: 'Triggers'),
    WorkflowStep(title: 'Review'),
  ];

  final List<LifecycleStateNode> _states = [
    const LifecycleStateNode(
      id: '1',
      label: 'Underwriter Review',
      subtitle: 'Initial policy assessment',
    ),
    const LifecycleStateNode(
      id: '2',
      label: 'Senior Underwriter',
      subtitle: 'Trigger: >₹1,000,000',
      isActive: true,
    ),
    const LifecycleStateNode(
      id: '3',
      label: 'VP Underwriting',
      subtitle: 'Trigger: >₹5,000,000',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WorkflowStepperWidget(
            steps: _steps
                .asMap()
                .entries
                .map(
                  (e) => e.value.copyWith(
                    isActive: e.key == _currentStep,
                    isCompleted: e.key < _currentStep,
                  ),
                )
                .toList(),
            currentIndex: _currentStep,
            onStepTap: (idx) => setState(() => _currentStep = idx),
          ),
          const SizedBox(height: 24),
          _buildStepContent(),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _saveWorkflow,
            icon: const Icon(Icons.save),
            label: const Text('Save Workflow'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveWorkflow() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppLoader(),
    );

    try {
      final client = ref.read(apiClientProvider);
      final payload = {
        'states': _states
            .map((s) => {'id': s.id, 'label': s.label, 'subtitle': s.subtitle})
            .toList(),
      };

      // Real API call
      await client.post('workflows', data: payload);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Workflow configuration saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving workflow: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _buildHierarchyStep();
      case 1:
        return _buildTriggersStep();
      case 2:
        return _buildReviewStep();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildHierarchyStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBox(message: 'Define the sequential review path for policies.'),
        const SizedBox(height: 16),
        LifecycleEditorWidget(states: _states, onAddState: _showAddStateDialog),
      ],
    );
  }

  Widget _buildTriggersStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InfoBox(
          message: 'Define automatic approval routing based on conditions.',
        ),
        SizedBox(height: 16),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                ListTile(
                  title: Text('Sum Insured > ₹1M'),
                  subtitle: Text('Routes to Senior Underwriter'),
                  trailing: Icon(Icons.settings),
                ),
                Divider(),
                ListTile(
                  title: Text('Sum Insured > ₹5M'),
                  subtitle: Text('Routes to VP Underwriting'),
                  trailing: Icon(Icons.settings),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('Add Trigger Condition'),
        ),
      ],
    );
  }

  Widget _buildReviewStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InfoBox(
          message: 'Review the workflow nodes and triggers before saving.',
        ),
        const SizedBox(height: 24),
        ..._states.map(
          (s) => ListTile(
            leading: const Icon(Icons.account_tree_outlined),
            title: Text(s.label),
            subtitle: Text(s.subtitle ?? 'Normal Review Path'),
          ),
        ),
      ],
    );
  }

  void _showAddStateDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Workflow State'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'State Name',
            hintText: 'e.g. Compliance Check',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _states.add(
                    LifecycleStateNode(
                      id: DateTime.now().toString(),
                      label: controller.text,
                      subtitle: 'Manual Step',
                    ),
                  );
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
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
      subtitle: subtitle,
      icon: icon,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }
}
