import 'package:flutter/material.dart';

/// Field definition for [DynamicFormWidget].
class DynamicFormField {
  const DynamicFormField({
    required this.key,
    required this.label,
    this.initialValue,
    this.hint,
    this.required = false,
    this.type = DynamicFormFieldType.text,
    this.options = const [],
    this.validator,
  });

  final String key;
  final String label;
  final String? initialValue;
  final String? hint;
  final bool required;
  final DynamicFormFieldType type;
  final List<String> options;
  final String? Function(String?)? validator;
}

enum DynamicFormFieldType { text, number, date, dropdown, checkbox, radio }

/// Renders a form from a list of [DynamicFormField]s. Used for claim submission,
/// risk profiling, and other admin forms.
class DynamicFormWidget extends StatefulWidget {
  const DynamicFormWidget({
    super.key,
    required this.fields,
    this.onSubmit,
    this.submitLabel = 'Submit',
  });

  final List<DynamicFormField> fields;
  final void Function(Map<String, dynamic>)? onSubmit;
  final String submitLabel;

  @override
  State<DynamicFormWidget> createState() => _DynamicFormWidgetState();
}

class _DynamicFormWidgetState extends State<DynamicFormWidget> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, dynamic> _values;
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _initValues();
  }

  void _initValues() {
    _values = {
      for (final f in widget.fields)
        f.key:
            f.initialValue ??
            (f.type == DynamicFormFieldType.checkbox ? false : ''),
    };
    for (final f in widget.fields) {
      if (f.type == DynamicFormFieldType.date ||
          f.type == DynamicFormFieldType.text ||
          f.type == DynamicFormFieldType.number) {
        _controllers[f.key] = TextEditingController(
          text: _values[f.key]?.toString(),
        );
      }
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  static const double _formMaxWidth = 520;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _formMaxWidth),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ...widget.fields.map(_buildField),
              if (widget.onSubmit != null) ...[
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(widget.submitLabel),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(DynamicFormField f) {
    final theme = Theme.of(context);

    return Padding(
      key: ValueKey(f.key),
      padding: const EdgeInsets.only(bottom: 20),
      child: switch (f.type) {
        DynamicFormFieldType.text => TextFormField(
          controller: _controllers[f.key],
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint,
            prefixIcon: _getIconForField(f.label),
          ),
          style: const TextStyle(fontWeight: FontWeight.w500),
          validator:
              f.validator ??
              (f.required
                  ? (v) => v == null || v.isEmpty ? 'Required' : null
                  : null),
          onChanged: (v) {
            _values[f.key] = v;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _formKey.currentState?.validate();
            });
          },
        ),
        DynamicFormFieldType.number => TextFormField(
          controller: _controllers[f.key],
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint,
            prefixIcon: const Icon(Icons.pin_outlined, size: 20),
          ),
          style: const TextStyle(fontWeight: FontWeight.w500),
          keyboardType: TextInputType.number,
          validator:
              f.validator ??
              (f.required
                  ? (v) => v == null || v.isEmpty ? 'Required' : null
                  : null),
          onChanged: (v) {
            _values[f.key] = v;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _formKey.currentState?.validate();
            });
          },
        ),
        DynamicFormFieldType.date => TextFormField(
          controller: _controllers[f.key],
          readOnly: true,
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint ?? 'Select date',
            prefixIcon: const Icon(Icons.calendar_today_outlined, size: 20),
            suffixIcon: Icon(
              Icons.expand_more,
              color: theme.colorScheme.primary,
            ),
          ),
          style: const TextStyle(fontWeight: FontWeight.w500),
          onTap: () async {
            final val = _values[f.key];
            final initial = (val is String && val.isNotEmpty)
                ? DateTime.tryParse(val) ?? DateTime.now()
                : DateTime.now();

            final date = await showDatePicker(
              context: context,
              initialDate: initial,
              firstDate: DateTime(1900),
              lastDate: DateTime(2100),
              builder: (context, child) {
                return Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      primary: theme.colorScheme.primary,
                      onPrimary: theme.colorScheme.onPrimary,
                      surface: theme.colorScheme.surface,
                      onSurface: theme.colorScheme.onSurface,
                    ),
                  ),
                  child: child!,
                );
              },
            );
            if (date != null) {
              final formatted = date.toIso8601String().split('T').first;
              setState(() {
                _values[f.key] = formatted;
                _controllers[f.key]?.text = formatted;
              });
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) _formKey.currentState?.validate();
              });
            }
          },
          validator:
              f.validator ??
              (f.required
                  ? (v) => v == null || v.isEmpty ? 'Required' : null
                  : null),
        ),
        DynamicFormFieldType.dropdown => LayoutBuilder(
          builder: (context, constraints) {
            return DropdownMenu<String>(
              width: constraints.maxWidth,
              initialSelection: (f.options.contains(_values[f.key]))
                  ? _values[f.key] as String?
                  : (f.initialValue != null &&
                            f.options.contains(f.initialValue)
                        ? f.initialValue
                        : null),
              label: Text(f.label + (f.required ? ' *' : '')),
              hintText: f.hint,
              dropdownMenuEntries: f.options.map((o) {
                return DropdownMenuEntry<String>(
                  value: o,
                  label: o,
                  style: MenuItemButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                );
              }).toList(),
              onSelected: (v) {
                setState(() {
                  _values[f.key] = v;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _formKey.currentState?.validate();
                  });
                });
              },
              inputDecorationTheme: theme.inputDecorationTheme.copyWith(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
              ),
              textStyle: const TextStyle(fontWeight: FontWeight.w500),
            );
          },
        ),
        DynamicFormFieldType.checkbox => Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: StatefulBuilder(
            builder: (context, setState) => CheckboxListTile(
              title: Text(
                f.label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              value: _values[f.key] as bool? ?? false,
              onChanged: (v) => setState(() => _values[f.key] = v ?? false),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
            ),
          ),
        ),
        DynamicFormFieldType.radio => Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                f.label + (f.required ? ' *' : ''),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...f.options.map(
                (o) => RadioListTile<String>(
                  title: Text(
                    o,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  value: o,
                  groupValue: _values[f.key] as String?,
                  onChanged: (v) => setState(() => _values[f.key] = v),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      },
    );
  }

  Widget? _getIconForField(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('name'))
      return const Icon(Icons.person_outline, size: 20);
    if (lower.contains('email'))
      return const Icon(Icons.email_outlined, size: 20);
    if (lower.contains('phone'))
      return const Icon(Icons.phone_outlined, size: 20);
    if (lower.contains('address'))
      return const Icon(Icons.location_on_outlined, size: 20);
    if (lower.contains('note') || lower.contains('desc'))
      return const Icon(Icons.notes_outlined, size: 20);
    return null;
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit?.call(Map.from(_values));
    }
  }
}
