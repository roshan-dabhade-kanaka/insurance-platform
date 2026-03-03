import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/widgets.dart';
import '../navigation/app_router.dart';

/// Lifecycle state editor. States are configured per product in the backend;
/// this page is a local preview. Use Workflow Configurator for API-backed setup.
class LifecycleStateEditorPage extends StatefulWidget {
  const LifecycleStateEditorPage({super.key});

  @override
  State<LifecycleStateEditorPage> createState() =>
      _LifecycleStateEditorPageState();
}

class _LifecycleStateEditorPageState extends State<LifecycleStateEditorPage> {
  final List<LifecycleStateNode> _states = [
    const LifecycleStateNode(id: '1', label: 'Initial Intake', isInitial: true),
    const LifecycleStateNode(id: '2', label: 'Awaiting Evidence', isActive: true),
    const LifecycleStateNode(id: '3', label: 'Under Review'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Lifecycle states are defined per product in the Workflow Configurator. '
                      'This screen is a local preview only.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go(AppRouter.workflowConfigurator),
                    child: const Text('Open Workflow Configurator'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Workflow preview',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          LifecycleEditorWidget(
            states: _states,
            onAddState: _showAddStateDialog,
            onTapState: (id) {
              setState(() {
                for (int i = 0; i < _states.length; i++) {
                  final s = _states[i];
                  _states[i] = LifecycleStateNode(
                    id: s.id,
                    label: s.label,
                    subtitle: s.subtitle,
                    isActive: s.id == id,
                    isInitial: s.isInitial,
                  );
                }
              });
            },
          ),
          const SizedBox(height: 24),
          DynamicFormWidget(
            fields: const [
              DynamicFormField(key: 'stateName', label: 'State name', required: true),
              DynamicFormField(key: 'transitions', label: 'Allowed transitions', hint: 'Comma-separated'),
            ],
            submitLabel: 'Add state (preview)',
            onSubmit: (values) {
              setState(() {
                _states.add(
                  LifecycleStateNode(
                    id: DateTime.now().toString(),
                    label: values['stateName'] ?? '',
                    subtitle: values['transitions'],
                  ),
                );
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('State added to preview')),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showAddStateDialog() {}
}
