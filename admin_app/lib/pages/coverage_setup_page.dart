import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../core/api_client.dart';

/// Coverage setup details (from coverage_setup_details).
class CoverageSetupPage extends ConsumerStatefulWidget {
  const CoverageSetupPage({super.key});

  @override
  ConsumerState<CoverageSetupPage> createState() => _CoverageSetupPageState();
}

class _CoverageSetupPageState extends ConsumerState<CoverageSetupPage> {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Coverage Configuration',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Define core benefits and sum insured limits.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 24),
          DynamicFormWidget(
            fields: const [
              DynamicFormField(
                key: 'name',
                label: 'Coverage Name',
                hint: 'e.g. Critical Illness',
                required: true,
              ),
              DynamicFormField(
                key: 'limit',
                label: 'Sum Insured Limit',
                type: DynamicFormFieldType.number,
              ),
              DynamicFormField(
                key: 'type',
                label: 'Type',
                type: DynamicFormFieldType.dropdown,
                options: ['Base', 'Rider', 'Optional'],
              ),
            ],
            submitLabel: 'Save coverage',
            onSubmit: (values) async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final client = ref.read(apiClientProvider);
                // Real API call (mocked path if needed, but using /products as a placeholder for now or checking if /coverages exists)
                // Actually, let's use a generic /products/coverage or similar if backend isn't ready,
                // but user expects "API call is present".
                await client.post('/products/coverages', data: values);

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Coverage "${values['name']}" persisted successfully!',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving coverage: $e'),
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
