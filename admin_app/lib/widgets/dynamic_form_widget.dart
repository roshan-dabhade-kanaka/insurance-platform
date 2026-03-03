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

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...widget.fields.map(_buildField),
          if (widget.onSubmit != null) ...[
            const SizedBox(height: 24),
            FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
          ],
        ],
      ),
    );
  }

  Widget _buildField(DynamicFormField f) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: switch (f.type) {
        DynamicFormFieldType.text => TextFormField(
          controller: _controllers[f.key],
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint,
          ),
          validator:
              f.validator ??
              (f.required
                  ? (v) => v == null || v.isEmpty ? 'Required' : null
                  : null),
          onChanged: (v) => _values[f.key] = v,
        ),
        DynamicFormFieldType.number => TextFormField(
          controller: _controllers[f.key],
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint,
          ),
          keyboardType: TextInputType.number,
          validator:
              f.validator ??
              (f.required
                  ? (v) => v == null || v.isEmpty ? 'Required' : null
                  : null),
          onChanged: (v) => _values[f.key] = v,
        ),
        DynamicFormFieldType.date => TextFormField(
          controller: _controllers[f.key],
          readOnly: true,
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
            hintText: f.hint ?? 'Select date',
            suffixIcon: const Icon(Icons.calendar_today),
          ),
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              final formatted = date.toIso8601String().split('T').first;
              setState(() {
                _values[f.key] = formatted;
                _controllers[f.key]?.text = formatted;
              });
            }
          },
          validator:
              f.validator ??
              (f.required
                  ? (v) => v == null || v.isEmpty ? 'Required' : null
                  : null),
        ),
        DynamicFormFieldType.dropdown => DropdownButtonFormField<String>(
          value: f.options.contains(_values[f.key])
              ? _values[f.key] as String?
              : (f.options.contains(f.initialValue) ? f.initialValue : null),
          decoration: InputDecoration(
            labelText: f.label + (f.required ? ' *' : ''),
          ),
          items: f.options
              .map((o) => DropdownMenuItem(value: o, child: Text(o)))
              .toList(),
          onChanged: (v) => setState(() => _values[f.key] = v),
        ),
        DynamicFormFieldType.checkbox => StatefulBuilder(
          builder: (context, setState) => CheckboxListTile(
            title: Text(f.label),
            value: _values[f.key] as bool? ?? false,
            onChanged: (v) => setState(() => _values[f.key] = v ?? false),
          ),
        ),
        DynamicFormFieldType.radio => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(f.label, style: Theme.of(context).textTheme.titleSmall),
            ...f.options.map(
              (o) => RadioListTile<String>(
                title: Text(o),
                value: o,
                groupValue: _values[f.key] as String?,
                onChanged: (v) => setState(() => _values[f.key] = v),
              ),
            ),
          ],
        ),
      },
    );
  }

  void _submit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit?.call(Map.from(_values));
    }
  }
}
