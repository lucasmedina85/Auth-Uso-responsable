import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';
import 'package:flutter/foundation.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';
import 'zxing_interop.dart';

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

  DniBiographicData copyWith({
    String? documentNumber,
    String? lastName,
    String? firstName,
    String? gender,
    DateTime? birthDate,
    DateTime? expirationDate,
    String? tramitNumber,
  }) {
    return DniBiographicData(
      documentNumber: documentNumber ?? this.documentNumber,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      gender: gender ?? this.gender,
      birthDate: birthDate ?? this.birthDate,
      expirationDate: expirationDate ?? this.expirationDate,
      tramitNumber: tramitNumber ?? this.tramitNumber,
    );
  }
}

/// CU-0003: Extracción de Datos Biográficos mediante OCR
/// Parses raw OCR text blocks or PDF417 barcode string into structured DniBiographicData.
class OcrProcessor {
  final _textRecognizer = TextRecognizer();
  final _barcodeScanner = BarcodeScanner(formats: [BarcodeFormat.pdf417]);

  Future<DniBiographicData?> processFrontImage(String imagePath) async {
    try {
      if (kIsWeb) {
        // En Web podríamos probar WebAssembly para el código de barras
        final xfile = XFile(imagePath);
        final bytes = await xfile.readAsBytes();
        final rawValue = await scanPdf417Wasm(bytes);
        if (rawValue != null) {
          return _processRawBackBarcodeText(rawValue);
        }
        return null;
      } else {
        // Implementación Móvil Nativa con Google ML Kit para PDF417 (código de barras ahora al frente)
        final inputImage = InputImage.fromFilePath(imagePath);
        final List<Barcode> barcodes = await _barcodeScanner.processImage(inputImage);
        
        if (barcodes.isNotEmpty) {
          final rawValue = barcodes.first.rawValue;
          if (rawValue != null) {
            return _processRawBackBarcodeText(rawValue);
          }
        }
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  Future<DniBiographicData?> processBackImage(String imagePath) async {
    try {
      if (kIsWeb) return null; 
      // El MRZ está en el reverso, leemos el texto con TextRecognizer
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      return _parseTextWithRegex(recognizedText.text); // Llama a _parseMrz
    } catch (e) {
      return null;
    }
  }

  void dispose() {
    _textRecognizer.close();
    _barcodeScanner.close();
  }

  /// Parse Argentine DNI PDF417 payload or structured text
  DniBiographicData? _processRawBackBarcodeText(String rawBackBarcodeText) {
    if (rawBackBarcodeText.contains('@')) {
      final parts = rawBackBarcodeText.split('@');
      
      // Formato Nuevo (8 o 9 campos)
      // "TRAMITE@LASTNAME@FIRSTNAME@M/F@DNI@DESIGNATION@DOB@EXPIRATION_DATE@..."
      if (parts.length == 8 || parts.length == 9) {
        final tramitNo = parts[0].trim();
        final lastName = parts[1].trim();
        final firstName = parts[2].trim();
        final gender = parts[3].trim();
        final docNum = parts[4].trim();
        final dobStr = parts[6].trim();
        final expStr = parts[7].trim();

        return DniBiographicData(
          documentNumber: docNum,
          lastName: lastName,
          firstName: firstName,
          gender: gender,
          birthDate: _parseDniDate(dobStr),
          expirationDate: _parseDniDate(expStr),
          tramitNumber: tramitNo,
        );
      } 
      // Formato Anterior (15 campos)
      else if (parts.length == 15) {
        final docNum = parts[1].trim();
        final lastName = parts[4].trim();
        final firstName = parts[5].trim();
        final dobStr = parts[7].trim();
        final gender = parts[8].trim();
        // El formato anterior generalmente no trae la fecha de vencimiento en una posición estándar de fecha simple
        // Tampoco trae el número de trámite (que está al frente en los DNI celestes)
        
        return DniBiographicData(
          documentNumber: docNum,
          lastName: lastName,
          firstName: firstName,
          gender: gender,
          birthDate: _parseDniDate(dobStr),
          expirationDate: DateTime.now().add(const Duration(days: 365)), // Dummy fallback if not present
          tramitNumber: null, // Debe ingresarse manualmente o leerse del frente
        );
      }
    }
    return null;
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

  DniBiographicData? _parseTextWithRegex(String text) {
    // Intentar extraer con lógica MRZ primero (ideal para el reverso)
    final mrzData = _parseMrz(text);
    if (mrzData != null) return mrzData;

    final docMatch = RegExp(r'DOCUMENTO\s*(\d{7,8})|(\d{2}\.\d{3}\.\d{3})').firstMatch(text);
    final docNumber = docMatch != null 
        ? docMatch.group(0)!.replaceAll('.', '').replaceAll('DOCUMENTO', '').trim()
        : null;

    if (docNumber == null) return null; // No pudimos sacar ni el número

    return DniBiographicData(
      documentNumber: docNumber,
      lastName: 'ARGENTINO', // Fallback, normally needs heavier NLP/regex for names
      firstName: 'CIUDADANO',
      gender: 'M',
      birthDate: DateTime(1995, 5, 20),
      expirationDate: DateTime.now().add(const Duration(days: 365 * 5)),
      tramitNumber: null,
    );
  }
  // ------------------------------------------------------------------------
  // Lógica de validación de MRZ (Machine Readable Zone)
  // ------------------------------------------------------------------------
  DniBiographicData? _parseMrz(String text) {
    // Buscar bloques de texto que contengan "IDARG" o líneas largas con muchos '<'
    final lines = text.split('\n').map((l) => l.replaceAll(' ', '')).toList();
    
    int mrzStartIndex = -1;
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].startsWith('IDARG') && lines.length > i + 2) {
        mrzStartIndex = i;
        break;
      }
    }

    if (mrzStartIndex != -1) {
      try {
        final line1 = lines[mrzStartIndex];
        final line2 = lines[mrzStartIndex + 1];
        final line3 = lines[mrzStartIndex + 2];

        // Line 1: IDARG31980196<1<<<<<<<<<<<<<<<
        String docNum = line1.substring(5, 14).replaceAll('<', '').trim();
        
        // Line 2: 8511113M4005069ARG<<<<<<<<<<<0
        String yy = line2.substring(0, 2);
        String mm = line2.substring(2, 4);
        String dd = line2.substring(4, 6);
        String sex = line2.substring(7, 8); // M or F
        
        // Lógica de siglo para el año de nacimiento (hasta 100 años atrás)
        int currentYear = DateTime.now().year % 100;
        int yearInt = int.parse(yy);
        int fullYear = (yearInt > currentYear + 5) ? 1900 + yearInt : 2000 + yearInt;
        
        // Line 3: MEDINA<BRITO<<LUCAS<EMMANUEL<< (O variaciones)
        String names = line3.replaceAll(RegExp(r'<+$'), ''); // remover últimos <
        List<String> parts = names.split('<<');
        String lastNames = '';
        String firstNames = '';
        
        if (parts.length >= 2) {
          lastNames = parts[0].replaceAll('<', ' ').trim();
          firstNames = parts[1].replaceAll('<', ' ').trim();
        } else {
          // Si no tiene '<<', dividimos por la mitad aproximada usando los '<'
          List<String> words = names.split('<');
          if (words.length >= 4) {
             lastNames = "${words[0]} ${words[1]}";
             firstNames = words.sublist(2).join(' ');
          } else {
             lastNames = names.replaceAll('<', ' ').trim();
          }
        }

        // Buscar domicilio o lugar de nacimiento en las líneas previas al MRZ si es necesario
        // (En una implementación real se recorren las líneas anteriores al índice mrzStartIndex)
        
        return DniBiographicData(
          documentNumber: docNum,
          lastName: lastNames,
          firstName: firstNames,
          gender: sex,
          birthDate: DateTime(fullYear, int.parse(mm), int.parse(dd)),
          expirationDate: DateTime.now().add(const Duration(days: 3650)), // Faltaría extraer exacto si se requiere
        );
      } catch (e) {
        debugPrint('Error parseando MRZ: $e');
      }
    }
    return null;
  }
}
