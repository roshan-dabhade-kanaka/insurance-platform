import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_provider.dart';
import '../widgets/widgets.dart';
import '../providers/quote_provider.dart';
import '../providers/admin_providers.dart';

class QuoteCreationPage extends ConsumerWidget {
  const QuoteCreationPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteState = ref.watch(quoteProvider);
    final user = ref.watch(authNotifierProvider).user;
    final productsAsync = ref.watch(productsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Create New Quote',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 24),
          if (quoteState.isLoading)
            const LinearProgressIndicator()
          else
            productsAsync.when(
              data: (products) => DynamicFormWidget(
                fields: [
                  DynamicFormField(
                    key: 'productVersionId',
                    label: 'Select Product',
                    type: DynamicFormFieldType.dropdown,
                    options: products.map((p) => '${p.name} ($p.id)').toList(),
                    required: true,
                  ),
                  const DynamicFormField(
                    key: 'firstName',
                    label: 'First Name',
                    required: true,
                  ),
                  const DynamicFormField(
                    key: 'lastName',
                    label: 'Last Name',
                    required: true,
                  ),
                  const DynamicFormField(
                    key: 'email',
                    label: 'Email',
                    required: true,
                  ),
                  const DynamicFormField(
                    key: 'coverageOptionId',
                    label: 'Coverage Option ID (Mock)',
                    required: true,
                    initialValue: '00000000-0000-0000-0000-000000000001',
                  ),
                  const DynamicFormField(
                    key: 'sumInsured',
                    label: 'Sum Insured',
                    type: DynamicFormFieldType.number,
                    required: true,
                  ),
                ],
                submitLabel: 'Generate Quote',
                onSubmit: (values) async {
                  try {
                    // Extract ID from name (ID) format
                    final productStr = values['productVersionId'] as String;
                    final productId = productStr.contains('(')
                        ? productStr.split('(').last.replaceAll(')', '').trim()
                        : productStr;

                    await ref.read(quoteProvider.notifier).createQuote({
                      'productVersionId':
                          productId, // Using product ID as version ID for mock simplicity
                      'applicantData': {
                        'firstName': values['firstName'],
                        'lastName': values['lastName'],
                        'email': values['email'],
                      },
                      'lineItems': [
                        {
                          'coverageOptionId': values['coverageOptionId'],
                          'sumInsured':
                              double.tryParse(values['sumInsured'] ?? '') ?? 0,
                        },
                      ],
                      'createdBy': user?.id ?? 'unknown',
                    });
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Quote created successfully!'),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to create quote: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('Error loading products: $e')),
            ),
        ],
      ),
    );
  }
}
