class QuoteField {
  final String fieldName;
  final String label;
  final String type;
  final bool required;
  final List<dynamic>? options;

  QuoteField({
    required this.fieldName,
    required this.label,
    required this.type,
    required this.required,
    this.options,
  });

  factory QuoteField.fromJson(Map<String, dynamic> json) {
    return QuoteField(
      fieldName: json['fieldName'] as String,
      label: json['label'] as String,
      type: json['type'] as String,
      required: json['required'] as bool? ?? false,
      options: json['options'] as List<dynamic>?,
    );
  }
}
