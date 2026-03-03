import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_providers.dart';
import '../widgets/widgets.dart';

/// Rule configuration engine UI (from rule_configuration_engine).
class RuleConfigurationPage extends ConsumerWidget {
  const RuleConfigurationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Underwriting Logic',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          rulesAsync.when(
            data: (rules) {
              final eligibility = (rules['eligibility'] as List?) ?? [];
              if (eligibility.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No eligibility rules found'),
                  ),
                );
              }

              return Column(
                children: eligibility.map((rule) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    child: ExpansionTile(
                      title: Text(rule['name'] ?? 'Unnamed Rule'),
                      subtitle: Text('Status: ${rule['status'] ?? 'Active'}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              RuleBuilderWidget(
                                logicLabel: 'AND',
                                rows: [
                                  // In a real app, mapping logic to rows would be complex
                                  // For now, we show the JSON and a placeholder builder
                                  const RuleBuilderRow(
                                    attribute: 'Condition',
                                    operator: 'Matches',
                                    value: 'Logic defined in JSON',
                                  ),
                                ],
                                onAddRule: () {},
                              ),
                              const SizedBox(height: 16),
                              JsonPreviewPanel(
                                title: 'Logic Definition',
                                data: rule['logic'] ?? {},
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text(
                'Error loading rules: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
