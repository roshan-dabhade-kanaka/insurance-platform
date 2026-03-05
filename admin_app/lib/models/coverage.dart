class Coverage {
  final String coverageId;
  final String coverageName;
  final String coverageCode;

  Coverage({
    required this.coverageId,
    required this.coverageName,
    required this.coverageCode,
  });

  factory Coverage.fromJson(Map<String, dynamic> json) {
    return Coverage(
      coverageId: json['coverageId'] as String,
      coverageName: json['coverageName'] as String,
      coverageCode: json['coverageCode'] as String,
    );
  }
}
