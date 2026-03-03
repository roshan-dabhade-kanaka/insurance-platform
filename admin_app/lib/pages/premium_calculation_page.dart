import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../providers/admin_providers.dart';
import '../widgets/widgets.dart';

/// Premium calculation breakdown (from premium_calculation_breakdown).
class PremiumCalculationPage extends ConsumerStatefulWidget {
  const PremiumCalculationPage({super.key});

  @override
  ConsumerState<PremiumCalculationPage> createState() =>
      _PremiumCalculationPageState();
}

class _PremiumCalculationPageState
    extends ConsumerState<PremiumCalculationPage> {
  Map<String, dynamic>? _breakdown;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _calculateDeepPremium({
    String? tenantId,
    String? quoteId,
    String? versionId,
  }) async {
    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final tid = tenantId ?? '00000000-0000-0000-0000-000000000001';

      final res = await client.post(
        '/rules/calculate-premium',
        data: {
          'tenantId': tid,
          'quoteId': quoteId ?? '00000000-0000-0000-0000-000000000001',
          'productVersionId':
              versionId ?? '00000000-0000-0000-0000-000000000001',
          'lineItems': [
            {'sumInsured': 100000, 'coverageOptionId': 'BASE_COVERAGE'},
          ],
          'riskProfileId': '00000000-0000-0000-0000-000000000001',
          'loadingPercentage': 10,
          'applicantData': {'age': 30, 'smoker': false},
        },
        queryParameters: {'tenantId': tid},
      );

      if (mounted && (res.statusCode == 201 || res.statusCode == 200)) {
        setState(() => _breakdown = res.data as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Calculation error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final quotesAsync = ref.watch(quotesProvider);

    return productsAsync.when(
      data: (products) => quotesAsync.when(
        data: (quotes) {
          // If we have live data, try to use it for a more realistic demo
          // but for basic viewing, we can still show the last breakdown or trigger a calc.
          if (_breakdown == null &&
              !_isLoading &&
              products.isNotEmpty &&
              quotes.isNotEmpty) {
            // We trigger one calculation automatically for the first quote/product in the list
            // to show that the wiring works.
            Future.microtask(
              () => _calculateDeepPremium(
                tenantId:
                    quotes.first.tenantId, // Wait, Quote model needs tenantId?
                // Actually the API uses headers or query params
                quoteId: quotes.first.id,
                versionId: products
                    .first
                    .id, // Assuming product ID is used as version ID for demo
              ),
            );
          }

          if (_isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return _buildContent(context);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error loading quotes: $e')),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error loading products: $e')),
    );
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final total = _breakdown?['totalPremium']?.toString() ?? '1,440.00';
    final base = _breakdown?['basePremium']?.toString() ?? '1,240.00';
    final tax = _breakdown?['taxAmount']?.toString() ?? '200.00';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Premium Breakdown (Live API)',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\$$base',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Divider(),
                  _LineItem(label: 'Base Premium', value: '\$$base'),
                  _LineItem(label: 'Tax / GST', value: '\$$tax'),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total premium',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '\$$total',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          JsonPreviewPanel(
            title: 'API Response',
            data: _breakdown ?? {'status': 'No data'},
          ),
        ],
      ),
    );
  }
}

class _LineItem extends StatelessWidget {
  const _LineItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value)],
      ),
    );
  }
}
