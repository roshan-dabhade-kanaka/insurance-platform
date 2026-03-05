import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../providers/admin_providers.dart';
import '../core/api_client.dart';

/// Coverage setup: define coverages (benefits, limits) that belong to a product version.
class CoverageSetupPage extends ConsumerStatefulWidget {
  const CoverageSetupPage({super.key});

  @override
  ConsumerState<CoverageSetupPage> createState() => _CoverageSetupPageState();
}

class _CoverageSetupPageState extends ConsumerState<CoverageSetupPage> {
  Product? _selectedProduct;
  ProductVersion? _selectedVersion;

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final theme = Theme.of(context);

    ref.listen<AsyncValue<List<Product>>>(productsProvider, (prev, next) {
      next.whenData((products) {
        if (_selectedProduct != null) {
          final updatedProduct = products
              .where((p) => p.id == _selectedProduct!.id)
              .firstOrNull;
          if (updatedProduct != null) {
            setState(() {
              _selectedProduct = updatedProduct;
              if (_selectedVersion != null) {
                _selectedVersion = updatedProduct.versions
                    .where((v) => v.id == _selectedVersion!.id)
                    .firstOrNull;
              }
            });
          }
        }
      });
    });

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Coverages are defined per product version. The "Coverage Code" should be a unique alphanumeric identifier (e.g., LIFE_BASE) used by the rule engine to reference this benefit.',
          ),
          const SizedBox(height: 24),

          // ── Product & Version Selection ──
          productsAsync.when(
            data: (products) => Row(
              children: [
                // Product Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: products.any((p) => p.id == _selectedProduct?.id)
                        ? _selectedProduct?.id
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Select Product',
                      border: OutlineInputBorder(),
                    ),
                    items: products.map((p) {
                      return DropdownMenuItem(value: p.id, child: Text(p.name));
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedProduct = products
                            .where((p) => p.id == val)
                            .firstOrNull;
                        _selectedVersion = null; // reset version
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                // Version Dropdown
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value:
                        (_selectedProduct?.versions.any(
                              (v) => v.id == _selectedVersion?.id,
                            ) ??
                            false)
                        ? _selectedVersion?.id
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Select Version',
                      border: OutlineInputBorder(),
                    ),
                    items:
                        _selectedProduct?.versions.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text('v${v.versionNumber} (${v.status})'),
                          );
                        }).toList() ??
                        [],
                    onChanged: _selectedProduct == null
                        ? null
                        : (val) {
                            setState(() {
                              _selectedVersion = _selectedProduct!.versions
                                  .where((v) => v.id == val)
                                  .firstOrNull;
                            });
                          },
                  ),
                ),
              ],
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error loading products: $e'),
          ),

          const SizedBox(height: 32),

          // ── Creation Form (only visible if version is selected) ──
          if (_selectedVersion != null) ...[
            Text(
              'Add New Coverage Option',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            DynamicFormWidget(
              fields: const [
                DynamicFormField(
                  key: 'name',
                  label: 'Coverage Name',
                  hint: 'e.g. Accidental Death',
                  required: true,
                ),
                DynamicFormField(
                  key: 'code',
                  label: 'Coverage Code',
                  hint: 'e.g. ADD_COVER',
                  required: true,
                ),
                DynamicFormField(
                  key: 'minSumInsured',
                  label: 'Min Sum Insured',
                  type: DynamicFormFieldType.number,
                ),
                DynamicFormField(
                  key: 'maxSumInsured',
                  label: 'Max Sum Insured',
                  type: DynamicFormFieldType.number,
                ),
                DynamicFormField(
                  key: 'isMandatory',
                  label: 'Is Mandatory?',
                  type: DynamicFormFieldType.checkbox,
                ),
              ],
              submitLabel: 'Create Coverage',
              onSubmit: (values) async {
                await _createCoverage(values);
              },
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              'Existing Coverages for v${_selectedVersion!.versionNumber}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_selectedVersion!.coverageOptions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('No coverage options defined for this version'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _selectedVersion!.coverageOptions.length,
                itemBuilder: (context, index) {
                  final coverage = _selectedVersion!.coverageOptions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.shield_outlined),
                      ),
                      title: Text(coverage.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${coverage.code} • ${coverage.isMandatory ? "Mandatory" : "Optional"}',
                          ),
                          if (coverage.minSumInsured != null ||
                              coverage.maxSumInsured != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Limit: ${coverage.minSumInsured ?? "0"} - ${coverage.maxSumInsured ?? "No Max"}',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.blue.shade700,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ] else
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 64),
              child: Center(
                child: Text('Select a product and version to manage coverages'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createCoverage(Map<String, dynamic> values) async {
    if (_selectedProduct == null || _selectedVersion == null) return;

    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppLoader(),
    );

    bool loaderPopped = false;

    try {
      final client = ref.read(apiClientProvider);
      final data = {
        ...values,
        'minSumInsured': values['minSumInsured']?.toString(),
        'maxSumInsured': values['maxSumInsured']?.toString(),
      };

      await client.post(
        'products/${_selectedProduct!.id}/versions/${_selectedVersion!.id}/coverages',
        data: data,
      );

      if (mounted) {
        navigator.pop(); // Close loader
        loaderPopped = true;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Coverage option created successfully'),
            backgroundColor: Colors.green,
          ),
        );
        // Refresh products to show updated coverages
        ref.invalidate(productsProvider);
        await ref.read(productsProvider.future);
      }
    } catch (e) {
      if (mounted && !loaderPopped) {
        navigator.pop(); // Close loader
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
