import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/coverage.dart';
import '../models/quote_field.dart';
import '../providers/admin_providers.dart';
import '../providers/product_service_provider.dart';
import '../providers/quote_provider.dart';
import '../widgets/widgets.dart';

class CreateQuoteScreen extends ConsumerStatefulWidget {
  const CreateQuoteScreen({super.key});

  @override
  ConsumerState<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends ConsumerState<CreateQuoteScreen> {
  final _formKey = GlobalKey<FormState>();

  // Static fields
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();

  Product? _selectedProduct;
  Coverage? _selectedCoverage;
  List<Coverage> _coverages = [];
  List<QuoteField> _quoteFields = [];
  bool _isLoadingMetaData = false;
  bool _isGenerating = false;

  // Dynamic fields
  final Map<String, dynamic> _dynamicValues = {};
  final Map<String, TextEditingController> _dynamicControllers = {};

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    for (var c in _dynamicControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _onProductChanged(Product? product) async {
    if (product == null) return;
    setState(() {
      _selectedProduct = product;
      _selectedCoverage = null;
      _coverages = [];
      _quoteFields = [];
      _isLoadingMetaData = true;

      // Clear dynamic fields
      for (var c in _dynamicControllers.values) {
        c.dispose();
      }
      _dynamicControllers.clear();
      _dynamicValues.clear();
    });

    try {
      final productService = ref.read(productServiceProvider);
      final results = await Future.wait([
        productService.getCoverages(product.id),
        productService.getQuoteFields(product.id),
      ]);

      setState(() {
        _coverages = results[0] as List<Coverage>;
        _quoteFields = results[1] as List<QuoteField>;

        // Initialize dynamic controllers
        for (var field in _quoteFields) {
          if (field.type != 'dropdown') {
            _dynamicControllers[field.fieldName] = TextEditingController();
          }
          _dynamicValues[field.fieldName] = null;
        }

        _isLoadingMetaData = false;
      });
    } catch (e) {
      setState(() => _isLoadingMetaData = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading product meta: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generateQuote() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCoverage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a coverage'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isGenerating = true);

    try {
      final quoteService = ref.read(quoteServiceProvider);

      // Collect dynamic data
      final Map<String, dynamic> dynamicData = {};
      double sumInsured = 0;
      for (var field in _quoteFields) {
        final val = _dynamicValues[field.fieldName];
        if (field.fieldName == 'sumInsured' ||
            field.fieldName.toLowerCase().contains('suminsured')) {
          sumInsured = double.tryParse(val?.toString() ?? '0') ?? 0;
        }
        dynamicData[field.fieldName] = val;
      }

      // Construct payload according to backend CreateQuoteDto
      final payload = {
        "productVersionId": _selectedProduct!.id,
        "applicantData": {
          "firstName": _firstNameController.text.trim(),
          "lastName": _lastNameController.text.trim(),
          "email": _emailController.text.trim(),
          ...dynamicData,
        },
        "lineItems": [
          {
            "coverageOptionId": _selectedCoverage!.coverageId,
            "sumInsured": sumInsured,
          },
        ],
        "createdBy": "admin", // In a real app, this comes from auth state
      };

      final newQuote = await quoteService.createQuote(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Quote generated successfully! ID: ${newQuote.id}'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/quote-lifecycle');
      }
    } catch (e) {
      String errorMessage = e.toString();

      // Handle DioException specifically to get the clean backend message
      if (e is DioException && e.response?.data != null) {
        final data = e.response!.data;
        if (data is Map && data.containsKey('message')) {
          final msg = data['message'];
          if (msg is List) {
            errorMessage = msg.join('\n');
          } else {
            errorMessage = msg.toString();
          }
        }
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Quote Generation Failed'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create New Quote'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: productsAsync.when(
        data: (products) => _buildForm(products),
        loading: () => const Center(child: AppLoader()),
        error: (e, s) => Center(child: Text('Error loading products: $e')),
      ),
    );
  }

  Widget _buildForm(List<Product> products) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSectionHeader('Applicant Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _firstNameController,
                      decoration: const InputDecoration(
                        labelText: 'First Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'First Name required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lastNameController,
                      decoration: const InputDecoration(
                        labelText: 'Last Name *',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (v) =>
                          v!.isEmpty ? 'Last Name required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email *',
                        prefixIcon: Icon(Icons.email_outlined),
                      ),
                      validator: (v) {
                        if (v!.isEmpty) return 'Email required';
                        if (!v.contains('@')) return 'Invalid email';
                        return null;
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader('Policy Details'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<Product>(
                      value: _selectedProduct,
                      decoration: const InputDecoration(
                        labelText: 'Product *',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                      items: products
                          .map(
                            (p) =>
                                DropdownMenuItem(value: p, child: Text(p.name)),
                          )
                          .toList(),
                      onChanged: _onProductChanged,
                      validator: (v) =>
                          v == null ? 'Please select a product' : null,
                    ),
                    if (_isLoadingMetaData)
                      const Padding(
                        padding: EdgeInsets.all(24.0),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_selectedProduct != null) ...[
                      const SizedBox(height: 16),
                      DropdownButtonFormField<Coverage>(
                        value: _selectedCoverage,
                        decoration: const InputDecoration(
                          labelText: 'Coverage *',
                          prefixIcon: Icon(Icons.security_outlined),
                        ),
                        items: _coverages
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(c.coverageName),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCoverage = v),
                        validator: (v) =>
                            v == null ? 'Coverage required' : null,
                      ),
                      const SizedBox(height: 16),
                      ..._buildDynamicFields(),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 48),
            FilledButton.icon(
              onPressed: _isGenerating ? null : _generateQuote,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.auto_awesome),
              label: Text(
                _isGenerating ? 'GENERATING...' : 'GENERATE QUOTE',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildDynamicFields() {
    return _quoteFields.map((field) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: _buildFieldWidget(field),
      );
    }).toList();
  }

  Widget _buildFieldWidget(QuoteField field) {
    switch (field.type) {
      case 'number':
        return TextFormField(
          controller: _dynamicControllers[field.fieldName],
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            prefixIcon: const Icon(Icons.calculate_outlined),
            prefixText: field.fieldName.toLowerCase().contains('sum')
                ? '₹ '
                : null,
          ),
          keyboardType: TextInputType.number,
          validator: (v) {
            if (field.required && (v == null || v.isEmpty))
              return '${field.label} required';
            if (v != null && v.isNotEmpty) {
              final n = double.tryParse(v);
              if (n == null) return 'Invalid number';
              if (field.fieldName.toLowerCase().contains('sum') && n <= 0)
                return '${field.label} must be > 0';
            }
            return null;
          },
          onChanged: (v) => _dynamicValues[field.fieldName] = v,
        );
      case 'date':
        return TextFormField(
          controller: _dynamicControllers[field.fieldName],
          readOnly: true,
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            prefixIcon: const Icon(Icons.calendar_today_outlined),
            suffixIcon: const Icon(Icons.event),
          ),
          onTap: () async {
            final currentVal = _dynamicValues[field.fieldName];
            final initial = (currentVal is String && currentVal.isNotEmpty)
                ? DateTime.tryParse(currentVal) ?? DateTime.now()
                : DateTime.now();

            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
            );
            if (date != null) {
              final formatted = DateFormat('yyyy-MM-dd').format(date);
              setState(() {
                _dynamicControllers[field.fieldName]!.text = formatted;
                _dynamicValues[field.fieldName] = formatted;
              });
            }
          },
          validator: (v) => field.required && (v == null || v.isEmpty)
              ? '${field.label} required'
              : null,
        );
      case 'dropdown':
        return DropdownButtonFormField<dynamic>(
          value: _dynamicValues[field.fieldName],
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            prefixIcon: const Icon(Icons.list_alt_outlined),
          ),
          items: (field.options ?? [])
              .map((o) => DropdownMenuItem(value: o, child: Text(o.toString())))
              .toList(),
          onChanged: (v) => setState(() => _dynamicValues[field.fieldName] = v),
          validator: (v) =>
              field.required && v == null ? '${field.label} required' : null,
        );
      default:
        return TextFormField(
          controller: _dynamicControllers[field.fieldName],
          decoration: InputDecoration(
            labelText: '${field.label}${field.required ? ' *' : ''}',
            prefixIcon: const Icon(Icons.text_fields_outlined),
          ),
          validator: (v) => field.required && (v == null || v.isEmpty)
              ? '${field.label} required'
              : null,
          onChanged: (v) => _dynamicValues[field.fieldName] = v,
        );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, left: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary.withOpacity(0.8),
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}
