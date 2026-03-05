class Condition {
  String fact;
  String operator;
  dynamic value;

  Condition({
    this.fact = 'age',
    this.operator = 'greaterThan',
    this.value = '',
  });

  Map<String, dynamic> toJson() {
    return {'fact': fact, 'operator': operator, 'value': _parseValue(value)};
  }

  dynamic _parseValue(dynamic val) {
    if (val is String) {
      return double.tryParse(val) ?? val;
    }
    return val;
  }
}
