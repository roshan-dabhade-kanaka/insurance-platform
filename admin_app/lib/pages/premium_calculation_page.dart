import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/error_handler.dart';
import '../providers/admin_providers.dart';
import '../providers/quote_provider.dart';
import '../widgets/widgets.dart';
import '../models/quote.dart';
import 'package:collection/collection.dart';
import '../auth/auth_provider.dart';
import '../auth/app_role.dart';
import '../navigation/app_router.dart';

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

  String? _selectedQuoteId;
  String? _selectedProductId;
  String? _selectedVersionId;
  String? _selectedCoverageCode;
  String? _selectedRiskProfileId;

  Quote? _selectedQuote;
  Product? _selectedProduct;
  ProductVersion? _selectedVersion;
  RiskProfile? _selectedRiskProfile;

  void _onQuoteSelected(String? quoteId, List<Product> products) {
    setState(() {
      _selectedQuoteId = quoteId;
      final quotesArr = ref.read(quoteProvider).asData?.value ?? [];
      _selectedQuote = quoteId == null
          ? null
          : quotesArr.firstWhere(
              (q) => q.id == quoteId,
              orElse: () => quotesArr.first,
            );

      if (_selectedQuote != null) {
        // Auto-find product and version
        Product? foundProduct;
        ProductVersion? foundVersion;

        for (var p in products) {
          for (var v in p.versions) {
            if (v.id == _selectedQuote!.productVersionId) {
              foundProduct = p;
              foundVersion = v;
              break;
            }
          }
          if (foundProduct != null) break;
        }

        if (foundProduct != null && foundVersion != null) {
          _selectedProductId = foundProduct.id;
          _selectedProduct = foundProduct;
          _selectedVersionId = foundVersion.id;
          _selectedVersion = foundVersion;

          // Default to first coverage UUID (id) if available.
          // We store the UUID so it matches the line item's coverageOptionId in the DB.
          if (foundVersion.coverageOptions.isNotEmpty) {
            _selectedCoverageCode = foundVersion.coverageOptions.first.id;
          }
          // Override with the actual coverage UUID from the quote's own line items
          // (the backend may have remapped the code to a different UUID on creation)
          if (_selectedQuote!.lineItems.isNotEmpty) {
            _selectedCoverageCode =
                _selectedQuote!.lineItems.first.coverageOptionId;
          }
        }

        // No longer using _riskSearchQuery as DropdownMenu handles it internally
      }
    });
  }

  Future<void> _calculate() async {
    if (_isLoading) return;
    if (_selectedQuoteId == null ||
        _selectedVersionId == null ||
        _selectedCoverageCode == null) {
      ResponseHandler.showError(
        context,
        'Please select a Quote, Product Version, and Coverage first.',
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final client = ref.read(apiClientProvider);
      final tid =
          _selectedQuote?.tenantId ?? '00000000-0000-0000-0000-000000000001';

      // Build line items: prefer the quote's own DB line items (resolved UUIDs).
      // Fallback to the manually-selected coverage code if no line items exist.
      final List<Map<String, dynamic>> lineItems;
      if (_selectedQuote != null && _selectedQuote!.lineItems.isNotEmpty) {
        lineItems = _selectedQuote!.lineItems
            .map(
              (li) => {
                'sumInsured': li.sumInsured,
                'coverageOptionId': li.coverageOptionId,
                'riderId': li.riderId,
              },
            )
            .toList();
      } else {
        // Fallback: no line items attached to the quote yet
        lineItems = [
          {'sumInsured': 100000, 'coverageOptionId': _selectedCoverageCode},
        ];
      }

      final res = await client.post(
        'rules/calculate-premium',
        data: {
          'tenantId': tid,
          'quoteId': _selectedQuoteId,
          'productVersionId': _selectedVersionId,
          'lineItems': lineItems,
          'riskProfileId':
              _selectedRiskProfileId ?? '00000000-0000-0000-0000-000000000001',
          'loadingPercentage':
              double.tryParse(
                _selectedRiskProfile?.loadingPercentage ?? '10',
              ) ??
              10,
          'applicantData':
              _selectedQuote?.applicantSnapshot ??
              _selectedRiskProfile?.profileData ??
              {'age': 30, 'smoker': false},
        },
        queryParameters: {'tenantId': tid},
      );

      if (mounted) {
        setState(() {
          _breakdown = res.data as Map<String, dynamic>;
        });
        ResponseHandler.showSuccess(context, 'Premium calculated successfully');
        ref.read(quoteProvider.notifier).fetchQuotes();
      }
    } catch (e) {
      if (mounted) {
        ResponseHandler.showError(
          context,
          e,
          fallback: 'Premium calculation failed',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final quotesAsync = ref.watch(quoteProvider);
    final riskProfilesAsync = ref.watch(riskProfilesProvider);
    final theme = Theme.of(context);

    final products = productsAsync.asData?.value ?? [];

    ref.listen<AsyncValue<List<Product>>>(productsProvider, (prev, next) {
      next.whenData((products) {
        if (_selectedProductId != null) {
          final updatedProduct = products
              .where((p) => p.id == _selectedProductId)
              .firstOrNull;
          if (updatedProduct != null) {
            setState(() {
              _selectedProduct = updatedProduct;
              if (_selectedVersionId != null) {
                _selectedVersion = updatedProduct.versions
                    .where((v) => v.id == _selectedVersionId)
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
                'Select a quote to automatically load its associated Product and Version patterns. Ensure Version and Coverage are populated before calculating.',
          ),
          const SizedBox(height: 24),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left: Selection Configuration
              Expanded(
                flex: 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.settings_outlined,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Configuration',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 32),

                        // 1. Quote Selection
                        quotesAsync.when(
                          loading: () => const AppLoader(),
                          error: (e, _) => Text('Error loading quotes: $e'),
                          data: (quotes) => DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: '1. Select Quote',
                              prefixIcon: Icon(Icons.description_outlined),
                              helperText: 'Auto-seeds Product/Version mapping',
                            ),
                            value: _selectedQuoteId,
                            items: quotes.map((q) {
                              return DropdownMenuItem(
                                value: q.id,
                                child: Text(
                                  '${q.quoteNumber} (${q.applicantRef ?? "No Name"})',
                                ),
                              );
                            }).toList(),
                            onChanged: (v) => _onQuoteSelected(v, products),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 2. Product (AUTO-SEEDED)
                        productsAsync.when(
                          loading: () => const AppLoader(),
                          error: (e, _) => Text('Error loading products: $e'),
                          data: (products) => DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: '2. Product',
                              prefixIcon: Icon(Icons.inventory_2_outlined),
                            ),
                            value: _selectedProductId,
                            items: products.map((p) {
                              return DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.name} (${p.code})'),
                              );
                            }).toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedProductId = v;
                                _selectedProduct = products.firstWhere(
                                  (p) => p.id == v,
                                );
                                _selectedVersionId = null;
                                _selectedVersion = null;
                                _selectedCoverageCode = null;
                              });
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // 3. Version (AUTO-SEEDED)
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '3. Product Version',
                            prefixIcon: Icon(Icons.history_outlined),
                          ),
                          disabledHint: const Text('Select a product first'),
                          value: _selectedVersionId,
                          items: _selectedProduct?.versions.map((v) {
                            return DropdownMenuItem(
                              value: v.id,
                              child: Text(
                                'Version ${v.versionNumber} (${v.status})',
                              ),
                            );
                          }).toList(),
                          onChanged: _selectedProduct == null
                              ? null
                              : (v) {
                                  setState(() {
                                    _selectedVersionId = v;
                                    _selectedVersion = _selectedProduct!
                                        .versions
                                        .firstWhere((ver) => ver.id == v);
                                    _selectedCoverageCode = null;
                                  });
                                },
                        ),
                        const SizedBox(height: 20),

                        // 4. Coverage
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: '4. Coverage Option',
                            prefixIcon: Icon(Icons.shield_outlined),
                          ),
                          disabledHint: const Text('Select a version first'),
                          value: _selectedCoverageCode,
                          items: _selectedVersion?.coverageOptions.map((c) {
                            return DropdownMenuItem(
                              value: c.id,
                              child: Text('${c.name} (${c.code})'),
                            );
                          }).toList(),
                          onChanged: _selectedVersion == null
                              ? null
                              : (v) {
                                  setState(() {
                                    _selectedCoverageCode = v;
                                  });
                                },
                        ),
                        const SizedBox(height: 20),

                        // 5. Risk Profile (Searchable Dropdown)
                        riskProfilesAsync.when(
                          loading: () => const AppLoader(),
                          error: (e, _) =>
                              Text('Error loading risk profiles: $e'),
                          data: (profiles) {
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                return DropdownMenu<String>(
                                  width: constraints.maxWidth,
                                  enableFilter: true,
                                  requestFocusOnTap: true,
                                  leadingIcon: const Icon(
                                    Icons.analytics_outlined,
                                  ),
                                  label: const Text(
                                    '5. Risk Profile (Optional)',
                                  ),
                                  inputDecorationTheme: InputDecorationTheme(
                                    filled: true,
                                    fillColor: theme.colorScheme.surfaceVariant
                                        .withOpacity(0.3),
                                    border: const OutlineInputBorder(),
                                  ),
                                  initialSelection: _selectedRiskProfileId,
                                  dropdownMenuEntries: profiles.map((p) {
                                    return DropdownMenuEntry<String>(
                                      value: p.id,
                                      label:
                                          '${p.applicantRef} (${p.riskBand})',
                                      leadingIcon: const Icon(
                                        Icons.person_outline,
                                        size: 18,
                                      ),
                                    );
                                  }).toList(),
                                  onSelected: (v) {
                                    setState(() {
                                      _selectedRiskProfileId = v;
                                      if (v != null) {
                                        _selectedRiskProfile = profiles
                                            .firstWhere((p) => p.id == v);
                                      }
                                    });
                                  },
                                );
                              },
                            );
                          },
                        ),

                        // FACT CHECK
                        if (_selectedQuote != null) ...[
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: theme.colorScheme.secondary.withOpacity(
                                  0.2,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.fact_check_outlined,
                                      size: 14,
                                      color: theme.colorScheme.secondary,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'FACT CHECK',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.secondary,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                _FactRow(
                                  label: 'Sum Insured:',
                                  value:
                                      '₹${(_selectedQuote!.lineItems.where((li) => li.coverageOptionId == _selectedCoverageCode).firstOrNull?.sumInsured ?? 0).toStringAsFixed(0)}',
                                ),
                                _FactRow(
                                  label: 'Applicant:',
                                  value:
                                      _selectedQuote!.applicantSnapshot['email']
                                          ?.toString() ??
                                      'N/A',
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 32),
                        if (_isLoading)
                          const AppLoader()
                        else
                          FilledButton.icon(
                            onPressed:
                                (_selectedQuoteId == null ||
                                    _selectedVersionId == null ||
                                    _selectedCoverageCode == null)
                                ? null
                                : _calculate,
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('Calculate Premium'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.all(20),
                              backgroundColor: Colors.blue.shade700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 24),
              // Right: Result Breakdown
              Expanded(
                flex: 3,
                child: _breakdown == null
                    ? Container(
                        height: 520,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant.withOpacity(
                            0.1,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.dividerColor.withOpacity(0.1),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calculate_outlined,
                              size: 64,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Run calculation to see results',
                              style: theme.textTheme.bodyLarge?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'Calculation Results',
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: Colors.green.withOpacity(
                                              0.3,
                                            ),
                                          ),
                                        ),
                                        child: const Text(
                                          'SUCCESS',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 32),
                                  _SummaryTile(
                                    label: 'Gross Premium',
                                    value:
                                        '₹${((_breakdown!['totalPremium'] is num ? _breakdown!['totalPremium'] : double.tryParse(_breakdown!['totalPremium']?.toString() ?? '0')) ?? 0).toStringAsFixed(2)}',
                                    isMain: true,
                                  ),
                                  const SizedBox(height: 20),
                                  _BreakdownRow(
                                    label: 'Base Premium',
                                    value:
                                        '₹${((_breakdown!['basePremium'] is num ? _breakdown!['basePremium'] : double.tryParse(_breakdown!['basePremium']?.toString() ?? '0')) ?? 0).toStringAsFixed(2)}',
                                  ),
                                  _BreakdownRow(
                                    label: 'Risk Loading',
                                    value:
                                        '+₹${((_breakdown!['riskLoading'] is num ? _breakdown!['riskLoading'] : double.tryParse(_breakdown!['riskLoading']?.toString() ?? '0')) ?? 0).toStringAsFixed(2)}',
                                  ),
                                  _BreakdownRow(
                                    label: 'Discounts',
                                    value:
                                        '-₹${((_breakdown!['discountAmount'] is num ? _breakdown!['discountAmount'] : double.tryParse(_breakdown!['discountAmount']?.toString() ?? '0')) ?? 0).toStringAsFixed(2)}',
                                    color: Colors.green,
                                  ),
                                  _BreakdownRow(
                                    label: 'Tax (GST)',
                                    value:
                                        '+₹${((_breakdown!['taxAmount'] is num ? _breakdown!['taxAmount'] : double.tryParse(_breakdown!['taxAmount']?.toString() ?? '0')) ?? 0).toStringAsFixed(2)}',
                                  ),
                                  const Divider(height: 32),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Snapshot ID',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                      TruncatedText(
                                        _breakdown!['snapshotId'] ?? 'N/A',
                                        maxLength: 16,
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                        ),
                                        tooltipLabel: 'Full Snapshot UUID',
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          JsonPreviewPanel(
                            title: 'Technical Trace',
                            data: _breakdown!,
                          ),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'What\'s Next?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedQuote?.status == 'DRAFT'
                                      ? 'The premium has been saved. Please SUBMIT this quote for underwriting review.'
                                      : 'The premium has been updated. Proceed to Underwriting to review existing cases.',
                                  style: const TextStyle(fontSize: 13),
                                ),
                                const SizedBox(height: 16),
                                if (_selectedQuote?.status == 'DRAFT')
                                  FilledButton.icon(
                                    onPressed: _isLoading
                                        ? null
                                        : () async {
                                            try {
                                              setState(() => _isLoading = true);
                                              await ref
                                                  .read(quoteProvider.notifier)
                                                  .submitQuote(
                                                    _selectedQuote!.id,
                                                  );
                                              if (mounted) {
                                                ResponseHandler.showSuccess(
                                                  context,
                                                  'Quote submitted successfully!',
                                                );
                                                // Refresh selected quote status
                                                final updated = ref
                                                    .read(quoteProvider)
                                                    .asData
                                                    ?.value
                                                    .firstWhereOrNull(
                                                      (q) =>
                                                          q.id ==
                                                          _selectedQuote!.id,
                                                    );
                                                if (updated != null) {
                                                  setState(() {
                                                    _selectedQuote = updated;
                                                  });
                                                }
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ResponseHandler.showError(
                                                  context,
                                                  e,
                                                );
                                              }
                                            } finally {
                                              if (mounted)
                                                setState(
                                                  () => _isLoading = false,
                                                );
                                            }
                                          },
                                    icon: const Icon(Icons.send),
                                    label: const Text(
                                      'Submit for Underwriting',
                                    ),
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Colors.blue.shade800,
                                    ),
                                  ),
                                if (_selectedQuote?.status != 'DRAFT' &&
                                    ref
                                            .read(authNotifierProvider)
                                            .user
                                            ?.hasAnyRole([
                                              AppRole.underwriter,
                                              AppRole.seniorUnderwriter,
                                              AppRole.admin,
                                            ]) ==
                                        true) ...[
                                  const SizedBox(height: 8),
                                  OutlinedButton.icon(
                                    onPressed: () => context.go(
                                      AppRouter.underwritingDecision,
                                    ),
                                    icon: const Icon(Icons.gavel),
                                    label: const Text(
                                      'Proceed to Underwriting',
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                TextButton.icon(
                                  onPressed: () =>
                                      context.go(AppRouter.quoteLifecycle),
                                  icon: const Icon(Icons.list_alt),
                                  label: const Text('View All Quotes'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isMain;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.isMain = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey, fontSize: isMain ? 14 : 12),
        ),
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: isMain ? theme.colorScheme.primary : null,
          ),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _BreakdownRow({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _FactRow extends StatelessWidget {
  final String label;
  final String value;

  const _FactRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            value,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
