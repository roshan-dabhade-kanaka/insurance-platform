import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/condition.dart';
import '../providers/rule_provider.dart';

import '../providers/admin_providers.dart';
import '../widgets/widgets.dart';

class RuleBuilderScreen extends ConsumerStatefulWidget {
  final String? versionId;
  final String? initialRuleType; // 'Eligibility' or 'Pricing'
  final InsuranceRule? existingRule;

  const RuleBuilderScreen({
    super.key,
    this.versionId,
    this.initialRuleType,
    this.existingRule,
  });

  @override
  ConsumerState<RuleBuilderScreen> createState() => _RuleBuilderScreenState();
}

class _RuleBuilderScreenState extends ConsumerState<RuleBuilderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ruleNameController = TextEditingController();

  late String _ruleType;
  late String _matchType;
  late List<Condition> _conditions;

  // Eligibility specific
  late String _eventType;
  final _reasonController = TextEditingController();

  // Pricing specific
  final _rateController = TextEditingController();

  Product? _selectedProduct;
  ProductVersion? _selectedVersion;

  @override
  void initState() {
    super.initState();
    _ruleType = widget.initialRuleType ?? 'Eligibility';
    _matchType = 'ALL';
    _conditions = [Condition()];
    _eventType = 'ineligible';

    if (widget.existingRule != null) {
      _ruleNameController.text = widget.existingRule!.name;
      _ruleType = widget.existingRule!.type == 'eligibility'
          ? 'Eligibility'
          : 'Pricing';
      _loadLogic(widget.existingRule!.logic);
    }
  }

  void _loadLogic(Map<String, dynamic> logic) {
    try {
      if (_ruleType == 'Pricing') {
        _rateController.text = logic['baseRate']?.toString() ?? '0.0';
        _matchType = 'ALL';
        _conditions = [Condition()];
      } else {
        final conditionsObj = logic['conditions'];
        if (conditionsObj != null) {
          if (conditionsObj['all'] != null) {
            _matchType = 'ALL';
            _parseConditions(conditionsObj['all']);
          } else if (conditionsObj['any'] != null) {
            _matchType = 'ANY';
            _parseConditions(conditionsObj['any']);
          }
        }

        final event = logic['event'];
        if (event != null) {
          final type = event['type'];
          final params = event['params'] ?? {};
          _eventType = type ?? 'ineligible';
          _reasonController.text = params['reason']?.toString() ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading logic: $e');
    }
  }

  void _parseConditions(dynamic list) {
    if (list is List) {
      _conditions = list.map((item) {
        final map = item as Map<String, dynamic>;
        return Condition(
          fact: map['fact']?.toString() ?? 'age',
          operator: map['operator']?.toString() ?? 'greaterThan',
          value: map['value'],
        );
      }).toList();
      if (_conditions.isEmpty) _conditions = [Condition()];
    }
  }

  @override
  void dispose() {
    _ruleNameController.dispose();
    _reasonController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _generateJson() {
    if (_ruleType == 'Pricing') {
      final map = <String, dynamic>{
        'baseRate': double.tryParse(_rateController.text) ?? 0.0,
        'factors': [],
      };
      return map;
    }

    final conditionList = _conditions.map((c) => c.toJson()).toList();
    final logic = {
      'conditions': {_matchType.toLowerCase(): conditionList},
      'event': {
        'type': _eventType,
        'params': {'reason': _reasonController.text.trim()},
      },
    };
    return logic;
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    final vId = widget.versionId ?? _selectedVersion?.id;
    if (vId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product version')),
      );
      return;
    }

    final logic = _generateJson();

    // Debug logging for the user to verify payload
    debugPrint('Saving Rule:');
    debugPrint('Name: ${_ruleNameController.text}');
    debugPrint('Type: $_ruleType');
    debugPrint('Logic: ${jsonEncode(logic)}');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppLoader(),
    );

    try {
      final ruleService = ref.read(ruleServiceProvider);

      if (widget.existingRule != null) {
        await ruleService.updateRule(
          ruleId: widget.existingRule!.id,
          ruleName: _ruleNameController.text.trim(),
          ruleType: _ruleType,
          versionId: vId,
          logic: logic,
        );
      } else {
        await ruleService.createRule(
          ruleName: _ruleNameController.text.trim(),
          ruleType: _ruleType,
          versionId: vId,
          logic: logic,
        );
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingRule != null
                  ? 'Rule updated successfully'
                  : 'Rule created successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(rulesProvider(vId));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final theme = Theme.of(context);
    final generatedJson = _generateJson();

    // Determine title
    final title = widget.existingRule != null
        ? 'Edit Rule'
        : 'Visual Rule Builder';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Selection (Hide if versionId is pre-provided)
              if (widget.versionId == null) ...[
                _buildSelectionHeader(productsAsync),
                const SizedBox(height: 24),
              ],

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Basic Information',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _ruleNameController,
                        decoration: const InputDecoration(
                          labelText: 'Rule Name',
                          hintText: 'e.g. Senior Citizen Exclusion',
                        ),
                        validator: (v) =>
                            v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _ruleType,
                              decoration: const InputDecoration(
                                labelText: 'Rule Type',
                              ),
                              items: ['Eligibility', 'Pricing'].map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(t),
                                );
                              }).toList(),
                              onChanged: widget.existingRule != null
                                  ? null // Disable type change on edit
                                  : (val) => setState(() => _ruleType = val!),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _matchType,
                              decoration: const InputDecoration(
                                labelText: 'Match Type',
                              ),
                              items: ['ALL', 'ANY'].map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text(
                                    t == 'ALL' ? 'ALL (AND)' : 'ANY (OR)',
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _matchType = val!),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Conditions Builder
              if (_ruleType == 'Eligibility') ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Conditions',
                              style: theme.textTheme.titleMedium,
                            ),
                            TextButton.icon(
                              onPressed: () =>
                                  setState(() => _conditions.add(Condition())),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Condition'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _conditions.length,
                          itemBuilder: (context, index) =>
                              _buildConditionRow(index, theme),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // Event Configuration
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Event Configuration',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      if (_ruleType == 'Eligibility') ...[
                        DropdownButtonFormField<String>(
                          value: _eventType,
                          decoration: const InputDecoration(
                            labelText: 'Event Type',
                          ),
                          items: ['eligible', 'ineligible'].map((t) {
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: (val) => setState(() => _eventType = val!),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _reasonController,
                          decoration: const InputDecoration(
                            labelText: 'Reason',
                            hintText: 'e.g. Age above 65',
                          ),
                          validator: (v) =>
                              _ruleType == 'Eligibility' &&
                                  (v == null || v.isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ] else ...[
                        const InfoBox(message: 'Event Type: calculate-premium'),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _rateController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Rate',
                            hintText: 'e.g. 0.02',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // JSON Preview
              ExpansionTile(
                title: const Text('Rule JSON Preview (Debugging)'),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    color: Colors.grey.shade100,
                    child: SelectableText(
                      const JsonEncoder.withIndent('  ').convert(generatedJson),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              FilledButton.icon(
                onPressed: _saveRule,
                icon: const Icon(Icons.save),
                label: Text(
                  widget.existingRule != null ? 'Update Rule' : 'Create Rule',
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionHeader(AsyncValue<List<Product>> productsAsync) {
    return productsAsync.when(
      data: (products) => Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: products.any((p) => p.id == _selectedProduct?.id)
                  ? _selectedProduct?.id
                  : null,
              decoration: const InputDecoration(
                labelText: 'Select Product',
                border: OutlineInputBorder(),
              ),
              items: products
                  .map(
                    (p) => DropdownMenuItem(value: p.id, child: Text(p.name)),
                  )
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedProduct = products
                      .where((p) => p.id == val)
                      .firstOrNull;
                  _selectedVersion = null;
                });
              },
            ),
          ),
          const SizedBox(width: 16),
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
                  _selectedProduct?.versions
                      .map(
                        (v) => DropdownMenuItem(
                          value: v.id,
                          child: Text('v${v.versionNumber}'),
                        ),
                      )
                      .toList() ??
                  [],
              onChanged: (val) {
                setState(() {
                  _selectedVersion = _selectedProduct?.versions
                      .where((v) => v.id == val)
                      .firstOrNull;
                });
              },
            ),
          ),
        ],
      ),
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildConditionRow(int index, ThemeData theme) {
    final condition = _conditions[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: condition.fact,
              decoration: const InputDecoration(labelText: 'Fact'),
              items: [
                'age',
                'sumInsured',
                'income',
                'policyTerm',
              ].map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
              onChanged: (val) => setState(() => condition.fact = val!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: condition.operator,
              decoration: const InputDecoration(labelText: 'Operator'),
              items:
                  [
                        {'val': 'greaterThan', 'lbl': '>'},
                        {'val': 'lessThan', 'lbl': '<'},
                        {'val': 'equal', 'lbl': '=='},
                        {'val': 'greaterThanInclusive', 'lbl': '>='},
                        {'val': 'lessThanInclusive', 'lbl': '<='},
                      ]
                      .map(
                        (o) => DropdownMenuItem(
                          value: o['val']!,
                          child: Text(o['lbl']!),
                        ),
                      )
                      .toList(),
              onChanged: (val) => setState(() => condition.operator = val!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: TextFormField(
              initialValue: condition.value?.toString(),
              decoration: const InputDecoration(labelText: 'Value'),
              keyboardType: TextInputType.number,
              onChanged: (val) => condition.value = val,
              validator: (v) => v == null || v.isEmpty ? '!' : null,
            ),
          ),
          IconButton(
            onPressed: () {
              if (_conditions.length > 1) {
                setState(() => _conditions.removeAt(index));
              }
            },
            icon: const Icon(Icons.delete_outline, color: Colors.red),
          ),
        ],
      ),
    );
  }
}
