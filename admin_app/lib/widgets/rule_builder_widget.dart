import 'package:flutter/material.dart';

/// Single rule row for [RuleBuilderWidget]: attribute, operator, value.
class RuleBuilderRow {
  const RuleBuilderRow({
    required this.attribute,
    required this.operator,
    required this.value,
    this.onDelete,
  });

  final String attribute;
  final String operator;
  final String value;
  final VoidCallback? onDelete;
}

/// Logic group (AND/OR) with nested rules. Used in eligibility/rule config UIs.
class RuleBuilderWidget extends StatelessWidget {
  final String logicLabel;
  final void Function(String)? onLogicChanged;
  final List<RuleBuilderRow> rows;
  final VoidCallback? onAddRule;
  final String addRuleLabel;
  final void Function(int index)? onRemoveRule;
  final void Function(int index, RuleBuilderRow newRow)? onUpdateRule;

  const RuleBuilderWidget({
    super.key,
    this.logicLabel = 'AND',
    this.onLogicChanged,
    this.rows = const [],
    this.onAddRule,
    this.addRuleLabel = 'Add condition',
    this.onRemoveRule,
    this.onUpdateRule,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'AND',
              label: Text('AND'),
              icon: Icon(Icons.join_inner),
            ),
            ButtonSegment(
              value: 'OR',
              label: Text('OR'),
              icon: Icon(Icons.join_full),
            ),
          ],
          selected: {logicLabel},
          onSelectionChanged: onLogicChanged != null
              ? (s) => onLogicChanged!(s.first)
              : null,
        ),
        const SizedBox(height: 16),
        ...rows.asMap().entries.map((e) {
          final i = e.key;
          final r = e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: onUpdateRule != null
                            ? () => _editField(context, i, r, 'attribute')
                            : null,
                        child: Text(
                          r.attribute,
                          style: theme.textTheme.titleSmall,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onUpdateRule != null
                            ? () => _editField(context, i, r, 'operator')
                            : null,
                        child: Text(
                          r.operator,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: InkWell(
                        onTap: onUpdateRule != null
                            ? () => _editField(context, i, r, 'value')
                            : null,
                        child: Text(r.value, style: theme.textTheme.bodyMedium),
                      ),
                    ),
                    if (onRemoveRule != null || r.onDelete != null)
                      IconButton(
                        onPressed: onRemoveRule != null
                            ? () => onRemoveRule!(i)
                            : r.onDelete,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Remove',
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (onAddRule != null)
          OutlinedButton.icon(
            onPressed: onAddRule,
            icon: const Icon(Icons.add_circle_outline),
            label: Text(addRuleLabel),
          ),
      ],
    );
  }

  void _editField(
    BuildContext context,
    int index,
    RuleBuilderRow row,
    String field,
  ) {
    String currentVal = field == 'attribute'
        ? row.attribute
        : (field == 'operator' ? row.operator : row.value);

    final List<String>? options = field == 'attribute'
        ? ['Age', 'Region', 'Gender', 'Occupation', 'BMI']
        : (field == 'operator'
              ? [
                  'Equals',
                  'Not Equals',
                  'Greater than',
                  'Less than',
                  'In',
                  'Not In',
                ]
              : null);

    if (options != null) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Select ${field[0].toUpperCase()}${field.substring(1)}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options
                .map(
                  (o) => ListTile(
                    title: Text(o),
                    onTap: () {
                      if (onUpdateRule != null) {
                        onUpdateRule!(
                          index,
                          RuleBuilderRow(
                            attribute: field == 'attribute' ? o : row.attribute,
                            operator: field == 'operator' ? o : row.operator,
                            value: row.value,
                            onDelete: row.onDelete,
                          ),
                        );
                      }
                      Navigator.pop(context);
                    },
                  ),
                )
                .toList(),
          ),
        ),
      );
    } else {
      final controller = TextEditingController(text: currentVal);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit Value'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(labelText: 'Value'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (onUpdateRule != null) {
                  onUpdateRule!(
                    index,
                    RuleBuilderRow(
                      attribute: row.attribute,
                      operator: row.operator,
                      value: controller.text,
                      onDelete: row.onDelete,
                    ),
                  );
                }
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      );
    }
  }
}
