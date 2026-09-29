import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class VerificationResult {
  final String matchType;
  final int faceMatchScore;
  final int livenessScore;
  final bool? isLatestDocument;

  VerificationResult({
    required this.matchType,
    required this.faceMatchScore,
    required this.livenessScore,
    this.isLatestDocument,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      matchType: json['matchType'] ?? 'UNKNOWN',
      faceMatchScore: json['faceMatchScore'] ?? 0,
      livenessScore: json['livenessScore'] ?? 0,
      isLatestDocument: json['isLatestDocument'],
    );
  }
}

class ApiService {
  // Use 10.0.2.2 for Android emulator to connect to localhost. 
  // Use localhost for Web/iOS simulator.
  static String get baseUrl {
    // Detectado y configurado automáticamente para la IP local actual de tu PC (192.168.0.14)
    if (kIsWeb) return 'http://localhost:8080';
    if (Platform.isAndroid) return 'http://192.168.0.14:8080'; 
    return 'http://192.168.0.14:8080';
  }

  static Future<VerificationResult> executeStandalonePipeline(
      String frontPath, String? backPath, String selfiePath, String vendorData) async {
    
    var request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/api/v1/verification/standalone'),
    );

    request.fields['vendor_data'] = vendorData;

    request.files.add(await http.MultipartFile.fromPath('front_image', frontPath));
    if (backPath != null && backPath.isNotEmpty) {
      request.files.add(await http.MultipartFile.fromPath('back_image', backPath));
    }
    request.files.add(await http.MultipartFile.fromPath('user_image', selfiePath));

    try {
      var streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);
        return VerificationResult.fromJson(jsonResponse);
      } else {
        throw Exception("Error del servidor: \${response.statusCode} - \${response.body}");
      }
    } catch (e) {
      throw Exception("Error de red: \$e");
    }
  }
}
