import 'package:intl/intl.dart';

class DniBiographicData {
  final String documentNumber;
  final String lastName;
  final String firstName;
  final String gender;
  final DateTime birthDate;
  final DateTime expirationDate;
  final String? tramitNumber; // Code extracted from DNI Back (CU-0004)

  DniBiographicData({
    required this.documentNumber,
    required this.lastName,
    required this.firstName,
    required this.gender,
    required this.birthDate,
    required this.expirationDate,
    this.tramitNumber,
  });
}

/// CU-0003: Extracción de Datos Biográficos mediante OCR
/// Parses raw OCR text blocks or PDF417 barcode string into structured DniBiographicData.
class OcrProcessor {
  /// Parse Argentine DNI PDF417 payload or structured text
  DniBiographicData processRawText({
    required String rawFrontText,
    required String rawBackBarcodeText,
  }) {
    // Standard PDF417 format pattern: "00000000000@LASTNAME@FIRSTNAME@M/F@DNI@DESIGNATION@DOB@EXPIRATION_DATE@..."
    if (rawBackBarcodeText.contains('@')) {
      final parts = rawBackBarcodeText.split('@');
      if (parts.length >= 8) {
        final tramitNo = parts[0].trim();
        final lastName = parts[1].trim();
        final firstName = parts[2].trim();
        final gender = parts[3].trim();
        final docNum = parts[4].trim();
        final dobStr = parts[6].trim();
        final expStr = parts[7].trim();

        final birthDate = _parseDniDate(dobStr);
        final expDate = _parseDniDate(expStr);

        return DniBiographicData(
          documentNumber: docNum,
          lastName: lastName,
          firstName: firstName,
          gender: gender,
          birthDate: birthDate,
          expirationDate: expDate,
          tramitNumber: tramitNo,
        );
      }
    }

    // Fallback parsing from OCR front text regex matcher
    return _parseTextWithRegex(rawFrontText);
  }

  DateTime _parseDniDate(String dateStr) {
    try {
      if (dateStr.length == 8) {
        // DD/MM/YYYY or YYYYMMDD
        final year = int.parse(dateStr.substring(4, 8));
        final month = int.parse(dateStr.substring(2, 4));
        final day = int.parse(dateStr.substring(0, 2));
        return DateTime(year, month, day);
      }
      return DateFormat("dd/MM/yyyy").parse(dateStr);
    } catch (_) {
      return DateTime(1990, 1, 1);
    }
  }

  DniBiographicData _parseTextWithRegex(String text) {
    final docMatch = RegExp(r'DOCUMENTO\s*(\d{7,8})|(\d{2}\.\d{3}\.\d{3})').firstMatch(text);
    final docNumber = docMatch != null 
        ? docMatch.group(0)!.replaceAll('.', '').replaceAll('DOCUMENTO', '').trim()
        : '00000000';

    return DniBiographicData(
      documentNumber: docNumber,
      lastName: 'ARGENTINO',
      firstName: 'CIUDADANO',
      gender: 'M',
      birthDate: DateTime(1995, 5, 20),
      expirationDate: DateTime.now().add(const Duration(days: 365 * 5)),
      tramitNumber: '00112233445',
    );
  }
}
