class SecurityFactorModel {
  final String name;
  final String description;
  final int contribution;
  final String status; // POSITIVE, NEUTRAL, NEGATIVE

  SecurityFactorModel({
    required this.name,
    required this.description,
    required this.contribution,
    required this.status,
  });

  factory SecurityFactorModel.fromJson(Map<String, dynamic> json) {
    return SecurityFactorModel(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      contribution: json['contribution'] as int? ?? 0,
      status: json['status'] as String? ?? 'NEUTRAL',
    );
  }
}

class SecurityScoreModel {
  final int score;
  final String level; // ALTO, MEDIO, BAJO
  final String levelDescription;
  final List<SecurityFactorModel> factors;

  SecurityScoreModel({
    required this.score,
    required this.level,
    required this.levelDescription,
    required this.factors,
  });

  factory SecurityScoreModel.fromJson(Map<String, dynamic> json) {
    final factorsRaw = json['factors'] as List<dynamic>? ?? [];
    return SecurityScoreModel(
      score: json['score'] as int? ?? 0,
      level: json['level'] as String? ?? 'BAJO',
      levelDescription: json['levelDescription'] as String? ?? '',
      factors: factorsRaw
          .map((f) => SecurityFactorModel.fromJson(f as Map<String, dynamic>))
          .toList(),
    );
  }
}
