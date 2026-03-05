import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_providers.dart';
import '../core/api_client.dart';
import '../widgets/widgets.dart';

/// Product list with search, filter pills, and cards (from product_configuration_list).
class ProductConfigurationPage extends ConsumerStatefulWidget {
  const ProductConfigurationPage({super.key});

  @override
  ConsumerState<ProductConfigurationPage> createState() =>
      _ProductConfigurationPageState();
}

class _ProductConfigurationPageState
    extends ConsumerState<ProductConfigurationPage> {
  String _filter = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
                'Products define the core insurance offerings. Use this page to manage product status (Active/Inactive) or add new products. Active products are available for new quotes.',
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                  decoration: InputDecoration(
                    hintText: 'Search product name or code...',
                    prefixIcon: const Icon(Icons.search, size: 22),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filled(
                onPressed: () => _showAddProductDialog(context),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 24),
          productsAsync.when(
            data: (products) => Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  label: Text('All (${products.length})'),
                  selected: _filter == 'All',
                  onSelected: (selected) {
                    if (selected) setState(() => _filter = 'All');
                  },
                ),
                FilterChip(
                  label: Text(
                    'Active (${products.where((p) => p.isActive).length})',
                  ),
                  selected: _filter == 'Active',
                  onSelected: (selected) {
                    if (selected) setState(() => _filter = 'Active');
                  },
                ),
                FilterChip(
                  label: Text(
                    'Inactive (${products.where((p) => !p.isActive).length})',
                  ),
                  selected: _filter == 'Inactive',
                  onSelected: (selected) {
                    if (selected) setState(() => _filter = 'Inactive');
                  },
                ),
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          productsAsync.when(
            data: (allProducts) {
              var products = _filter == 'Active'
                  ? allProducts.where((p) => p.isActive).toList()
                  : _filter == 'Inactive'
                  ? allProducts.where((p) => !p.isActive).toList()
                  : allProducts;
              if (_searchQuery.isNotEmpty) {
                products = products
                    .where(
                      (p) =>
                          p.name.toLowerCase().contains(_searchQuery) ||
                          p.code.toLowerCase().contains(_searchQuery),
                    )
                    .toList();
              }

              if (products.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Text('No products found'),
                  ),
                );
              }
              return Column(
                children: products.map((product) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: _ProductCard(
                      product: product,
                      onToggleActive: (v) =>
                          _setProductActive(context, product.id, v),
                      onAddVersion: () =>
                          _showAddVersionDialog(context, product),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const AppLoader(),
            error: (err, _) => Center(
              child: Text(
                'Error loading products: $err',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddVersionDialog(
    BuildContext context,
    Product product,
  ) async {
    DateTime effectiveFrom = DateTime.now();
    final changelogController = TextEditingController();
    final theme = Theme.of(context);

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Add Version — ${product.name}',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'A new DRAFT version will be auto-numbered. Fill in when it becomes effective.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Effective From picker
                  OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(
                      'Effective From: ${effectiveFrom.year}-${effectiveFrom.month.toString().padLeft(2, '0')}-${effectiveFrom.day.toString().padLeft(2, '0')}',
                    ),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: ctx,
                        initialDate: effectiveFrom,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                      );
                      if (picked != null) {
                        setDialogState(() => effectiveFrom = picked);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: changelogController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Changelog / Release Notes (optional)',
                      hintText: 'e.g. Revised premium loading rates for 2026',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Create Version'),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await _createVersion(
                            context,
                            product,
                            effectiveFrom,
                            changelogController.text.trim(),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createVersion(
    BuildContext context,
    Product product,
    DateTime effectiveFrom,
    String changelog,
  ) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        'products/${product.id}/versions',
        data: {
          'effectiveFrom':
              '${effectiveFrom.year}-${effectiveFrom.month.toString().padLeft(2, '0')}-${effectiveFrom.day.toString().padLeft(2, '0')}',
          if (changelog.isNotEmpty) 'changelog': changelog,
        },
      );
      ref.invalidate(productsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('New version created (DRAFT)'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.green.shade800,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create version: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setProductActive(
    BuildContext context,
    String productId,
    bool isActive,
  ) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.patch('products/$productId', data: {'isActive': isActive});
      ref.invalidate(productsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isActive
                  ? 'Product enabled'
                  : 'Product disabled (hidden from new quotes)',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    String type = 'LIFE';
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.add_box_outlined,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add New Product',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Define a new insurance product for the platform.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 32),
                TextField(
                  controller: nameController,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Product Name',
                    hintText: 'e.g. Life Safeguard Plus',
                    prefixIcon: Icon(Icons.label_outline, size: 20),
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    prefixIcon: Icon(Icons.category_outlined, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'HEALTH', child: Text('Health')),
                    DropdownMenuItem(value: 'AUTO', child: Text('Auto')),
                    DropdownMenuItem(value: 'LIFE', child: Text('Life')),
                    DropdownMenuItem(value: 'HOME', child: Text('Home')),
                  ],
                  borderRadius: BorderRadius.circular(16),
                  onChanged: (v) {
                    if (v != null) type = v;
                  },
                ),
                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 16,
                        ),
                      ),
                      onPressed: () async {
                        final name = nameController.text.trim();
                        if (name.isEmpty) return;

                        // Show standard loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (context) => const Center(
                            child: Card(
                              child: Padding(
                                padding: EdgeInsets.all(24.0),
                                child: AppLoader(),
                              ),
                            ),
                          ),
                        );

                        try {
                          final client = ref.read(apiClientProvider);
                          await client.post(
                            'products',
                            data: {
                              'name': name,
                              'code':
                                  'PROD-${DateTime.now().millisecondsSinceEpoch}',
                              'type': type,
                              'isActive': true,
                            },
                          );

                          if (context.mounted) {
                            Navigator.pop(context); // Close loading
                            Navigator.pop(context); // Close add dialog
                            ref.invalidate(productsProvider); // Refresh list
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Product created successfully',
                                ),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                backgroundColor: Colors.green.shade800,
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            Navigator.pop(context); // Close loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error creating product: $e'),
                                backgroundColor: theme.colorScheme.error,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Create Product'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ProductCard — shows product info, version chips, and Add Version button
// ─────────────────────────────────────────────────────────────────────────────
class _ProductCard extends StatelessWidget {
  final Product product;
  final void Function(bool) onToggleActive;
  final VoidCallback onAddVersion;

  const _ProductCard({
    required this.product,
    required this.onToggleActive,
    required this.onAddVersion,
  });

  Color _categoryBg(String type) {
    switch (type.toUpperCase()) {
      case 'HEALTH':
        return Colors.green.shade100;
      case 'AUTO':
        return Colors.blue.shade100;
      case 'LIFE':
        return Colors.purple.shade100;
      case 'HOME':
        return Colors.orange.shade100;
      default:
        return Colors.grey.shade100;
    }
  }

  Color _categoryFg(String type) {
    switch (type.toUpperCase()) {
      case 'HEALTH':
        return Colors.green;
      case 'AUTO':
        return Colors.blue;
      case 'LIFE':
        return Colors.purple;
      case 'HOME':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String type) {
    switch (type.toUpperCase()) {
      case 'HEALTH':
        return Icons.health_and_safety_outlined;
      case 'AUTO':
        return Icons.directions_car_outlined;
      case 'LIFE':
        return Icons.favorite_outline;
      case 'HOME':
        return Icons.home_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Color _versionStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'ACTIVE':
        return Colors.green;
      case 'DEPRECATED':
        return Colors.orange;
      case 'ARCHIVED':
        return Colors.red;
      default:
        return Colors.blueGrey; // DRAFT
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final versions = product.versions;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.4),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Product header row ──
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _categoryBg(product.type),
                  child: Icon(
                    _categoryIcon(product.type),
                    color: _categoryFg(product.type),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${product.type} • ${product.code}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // Active toggle
                Switch(value: product.isActive, onChanged: onToggleActive),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // ── Versions row ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Versions',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                // Version chips
                Expanded(
                  child: versions.isEmpty
                      ? Text(
                          'No versions yet',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontStyle: FontStyle.italic,
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          children: versions.map((v) {
                            final color = _versionStatusColor(v.status);
                            return Tooltip(
                              message:
                                  'Status: ${v.status}\nEffective: ${v.effectiveFrom}',
                              child: Chip(
                                label: Text(
                                  'v${v.versionNumber}',
                                  style: TextStyle(
                                    color: color,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                backgroundColor: color.withOpacity(0.1),
                                side: BorderSide(color: color.withOpacity(0.3)),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 0,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                // Add Version button
                Tooltip(
                  message: 'Add a new product version',
                  child: IconButton.outlined(
                    onPressed: onAddVersion,
                    icon: const Icon(Icons.add, size: 20),
                    style: IconButton.styleFrom(
                      foregroundColor: theme.colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
