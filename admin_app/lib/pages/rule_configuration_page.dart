import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/admin_providers.dart';
import '../widgets/widgets.dart';
import '../navigation/app_router.dart';

/// Rule configuration engine UI.
class RuleConfigurationPage extends ConsumerStatefulWidget {
  const RuleConfigurationPage({super.key});

  @override
  ConsumerState<RuleConfigurationPage> createState() =>
      _RuleConfigurationPageState();
}

class _RuleConfigurationPageState extends ConsumerState<RuleConfigurationPage> {
  Product? _selectedProduct;
  ProductVersion? _selectedVersion;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Rules are version-specific. Reference coverage options using their "Coverage Code" (e.g., DEATH_COV).',
          ),
          const SizedBox(height: 24),

          // ── Product & Version Selection ──
          productsAsync.when(
            data: (products) => Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<Product>(
                    value: _selectedProduct,
                    decoration: const InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(),
                    ),
                    items: products.map((p) {
                      return DropdownMenuItem(value: p, child: Text(p.name));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProduct = val;
                        _selectedVersion = null;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<ProductVersion>(
                    value: _selectedVersion,
                    decoration: const InputDecoration(
                      labelText: 'Select Version',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _selectedProduct?.versions.map((v) {
                          return DropdownMenuItem(
                            value: v,
                            child: Text('v${v.versionNumber} (${v.status})'),
                          );
                        }).toList() ??
                        [],
                    onChanged: (val) {
                      setState(() {
                        _selectedVersion = val;
                      });
                    },
                  ),
                ),
              ],
            ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
          ),

          const SizedBox(height: 32),

          if (_selectedVersion != null)
            _RulesListView(versionId: _selectedVersion!.id)
          else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Text('Select a product and version to manage rules'),
              ),
            ),
        ],
      ),
    );
  }
}

class _RulesListView extends ConsumerWidget {
  final String versionId;
  const _RulesListView({required this.versionId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(rulesProvider(versionId));

    return rulesAsync.when(
      data: (rules) {
        final eligibility =
            (rules['eligibility'] as List?)?.cast<InsuranceRule>() ?? [];
        final pricing =
            (rules['pricing'] as List?)?.cast<InsuranceRule>() ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Eligibility Rules Header ──
            _SectionHeader(
              title: 'Eligibility Rules',
              onAdd: () => context.push(
                AppRouter.ruleBuilder,
                extra: {'versionId': versionId, 'ruleType': 'Eligibility'},
              ),
            ),
            const SizedBox(height: 16),
            if (eligibility.isEmpty)
              const _EmptyHint(text: 'No eligibility rules found')
            else
              ...eligibility.map(
                (r) => _RuleTile(rule: r, versionId: versionId),
              ),

            const SizedBox(height: 40),
            const Divider(),
            const SizedBox(height: 24),

            // ── Pricing Rules Header ──
            _SectionHeader(
              title: 'Pricing Rules',
              onAdd: () => context.push(
                AppRouter.ruleBuilder,
                extra: {'versionId': versionId, 'ruleType': 'Pricing'},
              ),
            ),
            const SizedBox(height: 16),
            if (pricing.isEmpty)
              const _EmptyHint(text: 'No pricing rules found')
            else
              ...pricing.map((r) => _RuleTile(rule: r, versionId: versionId)),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final VoidCallback onAdd;
  const _SectionHeader({required this.title, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        ElevatedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add Rule'),
        ),
      ],
    );
  }
}

class _RuleTile extends StatelessWidget {
  final InsuranceRule rule;
  final String versionId;
  const _RuleTile({required this.rule, required this.versionId});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          rule.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Last updated: ${rule.id.split("-").first}',
        ), // Dummy timestamp logic
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(
          AppRouter.ruleBuilder,
          extra: {'versionId': versionId, 'existingRule': rule},
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(text, style: TextStyle(color: Colors.grey.shade500)),
      ),
    );
  }
}
