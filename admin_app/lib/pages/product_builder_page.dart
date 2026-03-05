import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/widgets.dart';
import '../core/api_client.dart';
import '../providers/admin_providers.dart';

/// Enterprise product builder (from enterprise_product_builder).
class ProductBuilderPage extends ConsumerStatefulWidget {
  const ProductBuilderPage({super.key});

  @override
  ConsumerState<ProductBuilderPage> createState() => _ProductBuilderPageState();
}

class _ProductBuilderPageState extends ConsumerState<ProductBuilderPage> {
  Map<String, dynamic> _currentConfig = {'name': '', 'coverages': []};

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const InfoBox(
            message:
                'Use the visual builder to define new insurance products. Set the line of business, code, and base configuration.',
          ),
          const SizedBox(height: 24),
          DynamicFormWidget(
            fields: const [
              DynamicFormField(
                key: 'name',
                label: 'Product name',
                required: true,
              ),
              DynamicFormField(key: 'code', label: 'Product code'),
              DynamicFormField(
                key: 'type',
                label: 'Line of business',
                type: DynamicFormFieldType.dropdown,
                options: ['Health', 'Auto', 'Property', 'Life'],
              ),
            ],
            submitLabel: 'Save product',
            onSubmit: (values) async {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AppLoader(),
              );

              try {
                final client = ref.read(apiClientProvider);
                final res = await client.post(
                  'products',
                  data: {...values, 'isActive': true},
                );

                if (mounted) {
                  Navigator.pop(context); // Close loading
                  setState(() => _currentConfig = res.data ?? values);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product saved successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  ref.invalidate(productsProvider);
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error saving product: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          ),
          const SizedBox(height: 24),
          JsonPreviewPanel(title: 'Product config', data: _currentConfig),
        ],
      ),
    );
  }
}
