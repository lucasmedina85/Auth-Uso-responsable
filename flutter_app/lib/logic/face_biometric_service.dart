import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'database_log_service.dart';

class FaceBiometricService {
  static const int maxFailedAttempts = 3;
  int _failedAttempts = 0;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true, // For smiling, eyes open probabilities
      enableTracking: true,
    ),
  );

  int get failedAttempts => _failedAttempts;

  /// Retorna un rostro válido si las condiciones de "Liveness Pasivo" se cumplen (CU-0014)
  Future<Face?> checkPassiveLiveness(InputImage image) async {
    final faces = await _faceDetector.processImage(image);
    
    if (faces.isEmpty) return null;

    final face = faces.first;
    
    // Verificación de Liveness Pasivo Básica
    // Requiere que ambos ojos estén abiertos y cierta probabilidad de rostro frontal
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;

    if (leftEyeOpen > 0.4 && rightEyeOpen > 0.4) {
      return face;
    }
    
    return null;
  }

  /// Cotejo 1:1 contra RENAPER (CU-0015 y CU-0016)
  Future<bool> matchWithRenaperTemplate(Face capturedFace) async {
    // Simulamos latencia de red contra RENAPER
    await Future.delayed(const Duration(seconds: 2));

    // Dummy score randomizado para simular la efectividad biométrica
    // En producción este vector cruzado devuelve un Score de similitud
    final score = Random().nextDouble(); // 0.0 a 1.0

    if (score > 0.3) { // 70% de chance de éxito (éxito simulado > 30% score random)
      _failedAttempts = 0;
      await DatabaseLogService().logEvent(
        'BIOMETRIC_MATCH', 
        'Cotejo facial exitoso contra RENAPER (score: \${(score * 100).toStringAsFixed(1)}%)', 
        'SUCCESS'
      );
      return true;
    } else {
      _failedAttempts++;
      
      final action = _failedAttempts >= maxFailedAttempts ? 'LOCKED' : 'FAILED';
      
      await DatabaseLogService().logEvent(
        'BIOMETRIC_MATCH_FAILED', 
        'Intento \$_failedAttempts fallido de cotejo facial (score: \${(score * 100).toStringAsFixed(1)}%)', 
        action
      );

      if (_failedAttempts >= maxFailedAttempts) {
        throw Exception("Demasiados intentos fallidos. Por razones de seguridad se bloqueó el registro.");
      }
      
      return false;
    }
  }

  void dispose() {
    _faceDetector.close();
  }
}
