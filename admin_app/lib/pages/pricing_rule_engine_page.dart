import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../core/api_client.dart';

/// Pricing rule engine (from pricing_rule_engine).
class PricingRuleEnginePage extends ConsumerStatefulWidget {
  const PricingRuleEnginePage({super.key});

  @override
  ConsumerState<PricingRuleEnginePage> createState() =>
      _PricingRuleEnginePageState();
}

class _PricingRuleEnginePageState extends ConsumerState<PricingRuleEnginePage> {
  final List<RuleBuilderRow> _rows = [
    const RuleBuilderRow(
      attribute: 'Age',
      operator: 'Greater than',
      value: '18',
    ),
    const RuleBuilderRow(attribute: 'Region', operator: 'In', value: 'EU, NA'),
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Configure the dynamic pricing logic used by the calculation engine. Rules define how applicant data affects the final premium.',
          ),
          const SizedBox(height: 24),
          RuleBuilderWidget(
            logicLabel: 'AND',
            rows: _rows,
            onAddRule: () {
              setState(() {
                _rows.add(
                  const RuleBuilderRow(
                    attribute: 'Age',
                    operator: 'Equals',
                    value: '25',
                  ),
                );
              });
            },
            onRemoveRule: (index) {
              setState(() {
                if (_rows.length > 1) _rows.removeAt(index);
              });
            },
            onUpdateRule: (index, newRow) {
              setState(() {
                _rows[index] = newRow;
              });
            },
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton.icon(
                onPressed: _saveConfiguration,
                icon: const Icon(Icons.save),
                label: const Text('Save Configuration'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _rows.clear();
                    _rows.add(
                      const RuleBuilderRow(
                        attribute: 'Age',
                        operator: 'Greater than',
                        value: '18',
                      ),
                    );
                  });
                },
                icon: const Icon(Icons.history),
                label: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          JsonPreviewPanel(
            title: 'Active Pricing Configuration',
            data: {
              'rules': _rows
                  .map(
                    (r) => {
                      'attr': r.attribute,
                      'op': r.operator,
                      'val': r.value,
                    },
                  )
                  .toList(),
              'defaultFactor': 1.0,
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveConfiguration() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppLoader(),
    );

    try {
      final client = ref.read(apiClientProvider);
      final payload = {
        'rules': _rows
            .map(
              (r) => {
                'attribute': r.attribute,
                'operator': r.operator,
                'value': r.value,
              },
            )
            .toList(),
      };

      // Real API call
      await client.post('rules/pricing', data: payload);

      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pricing rules saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving rules: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
