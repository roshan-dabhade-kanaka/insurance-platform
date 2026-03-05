import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/condition.dart';
import '../providers/rule_provider.dart';
import '../providers/admin_providers.dart';
import '../widgets/widgets.dart';

class RuleVisualEditor extends ConsumerStatefulWidget {
  final String versionId;
  final String? ruleId;
  final String initialRuleType; // 'Eligibility' or 'Pricing'
  final Map<String, dynamic>? initialLogic;
  final String? initialName;
  final VoidCallback onSaved;
  final VoidCallback onCancel;

  const RuleVisualEditor({
    super.key,
    required this.versionId,
    required this.onSaved,
    required this.onCancel,
    this.ruleId,
    this.initialRuleType = 'Eligibility',
    this.initialLogic,
    this.initialName,
  });

  @override
  ConsumerState<RuleVisualEditor> createState() => _RuleVisualEditorState();
}

class _RuleVisualEditorState extends ConsumerState<RuleVisualEditor> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _ruleNameController;
  late String _ruleType;
  late String _matchType;
  late List<Condition> _conditions;

  // Eligibility specific
  late String _eventType;
  late TextEditingController _reasonController;

  // Pricing specific
  late TextEditingController _rateController;

  @override
  void initState() {
    super.initState();
    _ruleNameController = TextEditingController(text: widget.initialName ?? '');
    _ruleType = widget.initialRuleType;
    _matchType = 'ALL';
    _conditions = [Condition()];
    _eventType = 'ineligible';
    _reasonController = TextEditingController();
    _rateController = TextEditingController();

    if (widget.initialLogic != null) {
      _loadLogic(widget.initialLogic!);
    }
  }

  void _loadLogic(Map<String, dynamic> logic) {
    try {
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
        if (_ruleType == 'Eligibility') {
          _eventType = type ?? 'ineligible';
          _reasonController.text = params['reason']?.toString() ?? '';
        } else {
          _rateController.text = params['rate']?.toString() ?? '0.0';
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
    final conditionList = _conditions.map((c) => c.toJson()).toList();
    final logic = {
      'conditions': {_matchType.toLowerCase(): conditionList},
      'event': {
        'type': _ruleType == 'Eligibility' ? _eventType : 'calculate-premium',
        'params': _ruleType == 'Eligibility'
            ? {'reason': _reasonController.text}
            : {'rate': double.tryParse(_rateController.text) ?? 0.0},
      },
    };
    return logic;
  }

  Future<void> _saveRule() async {
    if (!_formKey.currentState!.validate()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AppLoader(),
    );

    try {
      final ruleService = ref.read(ruleServiceProvider);
      final logic = _generateJson();

      await ruleService.createRule(
        ruleName: _ruleNameController.text,
        ruleType: _ruleType,
        versionId: widget.versionId,
        logic: logic,
      );

      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Rule saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
        ref.invalidate(rulesProvider(widget.versionId));
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close loader
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final generatedJson = _generateJson();

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: widget.onCancel,
                icon: const Icon(Icons.close),
              ),
              Text(
                widget.ruleId == null ? 'New Visual Rule' : 'Edit Rule',
                style: theme.textTheme.titleLarge,
              ),
              const Spacer(),
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _saveRule,
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save Rule'),
              ),
            ],
          ),
          const Divider(),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Basic Information', style: theme.textTheme.titleSmall),
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
                            return DropdownMenuItem(value: t, child: Text(t));
                          }).toList(),
                          onChanged: widget.ruleId != null
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
                          onChanged: (val) => setState(() => _matchType = val!),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Conditions', style: theme.textTheme.titleSmall),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _conditions.add(Condition())),
                        icon: const Icon(Icons.add, size: 18),
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
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: theme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Event & Results', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 16),
                  if (_ruleType == 'Eligibility') ...[
                    DropdownButtonFormField<String>(
                      value: _eventType,
                      decoration: const InputDecoration(
                        labelText: 'Eligibility Result',
                      ),
                      items: ['eligible', 'ineligible'].map((t) {
                        return DropdownMenuItem(
                          value: t,
                          child: Text(t.toUpperCase()),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _eventType = val!),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _reasonController,
                      decoration: const InputDecoration(
                        labelText: 'Reason / Message',
                        hintText: 'e.g. Applicant age is above 65',
                      ),
                      validator: (v) =>
                          _ruleType == 'Eligibility' && (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ] else ...[
                    const InfoBox(message: 'Pricing Event: calculate-premium'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _rateController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Premium Rate (Decimal)',
                        hintText: 'e.g. 0.02',
                        suffixText: 'pct',
                      ),
                      validator: (v) =>
                          _ruleType == 'Pricing' && (v == null || v.isEmpty)
                          ? 'Required'
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text(
              'Generated Rule Source (JSON)',
              style: TextStyle(fontSize: 14),
            ),
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SelectableText(
                  const JsonEncoder.withIndent('  ').convert(generatedJson),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionRow(int index, ThemeData theme) {
    final condition = _conditions[index];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: condition.fact,
              decoration: const InputDecoration(
                labelText: 'Fact',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: ['age', 'sumInsured', 'income', 'policyTerm']
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(f, style: const TextStyle(fontSize: 13)),
                    ),
                  )
                  .toList(),
              onChanged: (val) => setState(() => condition.fact = val!),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: DropdownButtonFormField<String>(
              value: condition.operator,
              decoration: const InputDecoration(
                labelText: 'Op',
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
                          child: Text(
                            o['lbl']!,
                            style: const TextStyle(fontSize: 13),
                          ),
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
              decoration: const InputDecoration(
                labelText: 'Value',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 13),
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
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
