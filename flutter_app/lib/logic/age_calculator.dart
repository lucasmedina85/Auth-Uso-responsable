/// CU-0007: Cálculo de Mayoría de Edad
/// Strict verification of user age (>= 18 years old) enforcing Responsible Gaming regulations.
class AgeCalculator {
  static const int minLegalAge = 18;

  /// Calculate precise age based on birth date and reference date (default: now)
  int calculateAge(DateTime birthDate, {DateTime? referenceDate}) {
    final today = referenceDate ?? DateTime.now();
    int age = today.year - birthDate.year;

    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  /// Verifies if user satisfies legal age requirement (18+)
  bool isAdult(DateTime birthDate, {DateTime? referenceDate}) {
    return calculateAge(birthDate, referenceDate: referenceDate) >= minLegalAge;
  }
}
