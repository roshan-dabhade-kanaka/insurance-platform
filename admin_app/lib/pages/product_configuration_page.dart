import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/admin_providers.dart';
import '../core/api_client.dart';

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

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search product name...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
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
          const SizedBox(height: 12),
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
              ],
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          productsAsync.when(
            data: (allProducts) {
              final products = _filter == 'Active'
                  ? allProducts.where((p) => p.isActive).toList()
                  : allProducts;

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
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getCategoryColor(product.type),
                          child: Icon(
                            _getCategoryIcon(product.type),
                            color: _getCategoryDarkColor(product.type),
                          ),
                        ),
                        title: Text(product.name),
                        subtitle: Text('${product.type} • ID: ${product.code}'),
                        trailing: Chip(
                          label: Text(product.isActive ? 'Active' : 'Inactive'),
                          backgroundColor: product.isActive
                              ? Colors.green.shade50
                              : Colors.grey.shade50,
                          labelStyle: TextStyle(
                            color: product.isActive
                                ? Colors.green.shade700
                                : Colors.grey.shade700,
                          ),
                        ),
                        onTap: () {
                          // TODO: Navigate to details
                        },
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
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

  void _showAddProductDialog(BuildContext context) {
    final nameController = TextEditingController();
    String category = 'Life';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Product Name',
                hintText: 'e.g. Life Safeguard',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: category,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                'Health',
                'Auto',
                'Life',
                'Home',
              ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) {
                if (v != null) category = v;
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text;
              if (name.isEmpty) return;

              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) =>
                    const Center(child: CircularProgressIndicator()),
              );

              try {
                final client = ref.read(apiClientProvider);
                // Real API call
                await client.post(
                  '/products',
                  data: {
                    'name': name,
                    'type': category,
                    'isActive': true,
                    'code': 'PROD-${DateTime.now().millisecondsSinceEpoch}',
                  },
                );

                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  Navigator.pop(context); // Close add dialog
                  ref.invalidate(productsProvider); // Refresh list
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Product created successfully'),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  Navigator.pop(context); // Close loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error creating product: $e')),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  Color _getCategoryColor(String type) {
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

  Color _getCategoryDarkColor(String type) {
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

  IconData _getCategoryIcon(String type) {
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
}
