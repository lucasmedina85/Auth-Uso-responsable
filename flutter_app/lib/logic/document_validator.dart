/// CU-0005: Validación de Vigencia de Documento
/// Verifies if the extracted DNI expiration date is later than the current network time.
class DocumentValidator {
  /// Check if the document expiration date is still valid
  bool isDocumentValid(DateTime expirationDate, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    // Expiration date must be strictly strictly after today's date
    return expirationDate.isAfter(now);
  }

  /// Calculates remaining days of validity
  int getRemainingDaysValid(DateTime expirationDate, {DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();
    return expirationDate.difference(now).inDays;
  }
}
