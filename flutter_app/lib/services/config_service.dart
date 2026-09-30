import 'dart:developer';
import 'package:dio/dio.dart';
import '../core/network/dio_client.dart';
import 'package:package_info_plus/package_info_plus.dart';

class ConfigService {
  static Future<Map<String, dynamic>?> checkVersionRequirement() async {
    try {
      final dio = DioClient().dio;
      // In a real scenario, this fetches from GET /config/version
      // We'll mock the response to test the logic if the endpoint doesn't exist
      Response response;
      try {
         response = await dio.get('/config/version');
      } catch (e) {
         // Mock fallback
         response = Response(
           requestOptions: RequestOptions(path: ''),
           statusCode: 200,
           data: {
             'minimumRequiredVersion': '1.0.0', // Set to 2.0.0 to trigger update
             'isUpdateMandatory': true,
           }
         );
      }
      
      if (response.statusCode == 200) {
        final PackageInfo packageInfo = await PackageInfo.fromPlatform();
        String currentVersion = packageInfo.version;
        if (currentVersion.isEmpty) currentVersion = '1.0.0';
        
        String requiredVersion = response.data['minimumRequiredVersion'];
        
        // Simple version comparison (e.g. 1.0.0 < 1.2.0)
        bool needsUpdate = _isVersionLower(currentVersion, requiredVersion);
        
        return {
          'needsUpdate': needsUpdate,
          'currentVersion': currentVersion,
          'requiredVersion': requiredVersion,
          'isMandatory': response.data['isUpdateMandatory'] ?? true,
        };
      }
    } catch (e) {
      log('Error checking version: $e');
    }
    return null;
  }
  
  static bool _isVersionLower(String current, String required) {
    List<int> currentParts = current.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> requiredParts = required.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    
    for (int i = 0; i < 3; i++) {
      int c = i < currentParts.length ? currentParts[i] : 0;
      int r = i < requiredParts.length ? requiredParts[i] : 0;
      if (c < r) return true;
      if (c > r) return false;
    }
    return false;
  }
}
