import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'database_log_service.dart';

class FaceBiometricService {
  static const int maxFailedAttempts = 3;
  int _failedAttempts = 0;
  int? _lastLivenessScore;
  int? _lastFaceMatchScore;

  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      enableContours: true,
      enableLandmarks: true,
      enableClassification: true, // For smiling, eyes open probabilities
      enableTracking: true,
    ),
  );

  int get failedAttempts => _failedAttempts;

  /// Último score de liveness pasivo calculado localmente (0-100) (CU-0014 / CU-0023)
  int? get lastLivenessScore => _lastLivenessScore;

  /// Último score de cotejo facial 1:1 contra RENAPER (0-100) (CU-0015 / CU-0023)
  int? get lastFaceMatchScore => _lastFaceMatchScore;

  /// Retorna un rostro válido si las condiciones de "Liveness Pasivo" se cumplen (CU-0014)
  Future<Face?> checkPassiveLiveness(InputImage image) async {
    final faces = await _faceDetector.processImage(image);
    
    if (faces.isEmpty) {
      _lastLivenessScore = 0;
      return null;
    }

    final face = faces.first;
    
    // Verificación de Liveness Pasivo Básica
    // Requiere que ambos ojos estén abiertos y cierta probabilidad de rostro frontal
    final leftEyeOpen = face.leftEyeOpenProbability ?? 0.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 0.0;
    final headEulerY = face.headEulerAngleY ?? 0.0;
    final headEulerZ = face.headEulerAngleZ ?? 0.0;
    final headEulerX = face.headEulerAngleX ?? 0.0;

    // Calidad de ojos abiertos (0.0 - 1.0)
    final avgEyes = (leftEyeOpen + rightEyeOpen) / 2.0;
    // Factor de orientación frontal: penaliza desviaciones mayores a 45 grados
    final angleDev = (headEulerY.abs() + headEulerZ.abs() + headEulerX.abs()) / 3.0;
    final orientationFactor = (1.0 - (angleDev / 45.0)).clamp(0.0, 1.0);

    // Score liveness compuesto local (0 - 100)
    final calculatedLiveness = ((avgEyes * 0.7 + orientationFactor * 0.3) * 100.0).round().clamp(0, 100);
    _lastLivenessScore = calculatedLiveness;

    if (leftEyeOpen > 0.4 && rightEyeOpen > 0.4) {
      return face;
    }
    
    return null;
  }

  /// Cotejo 1:1 contra RENAPER (CU-0015, CU-0016 y CU-0023)
  ///
  /// NOTA TÉCNICA / CU-0023:
  /// El cotejo biométrico 1:1 local contra plantilla RENAPER es actualmente simulado de forma dinámica,
  /// a la espera de la integración del SDK/API oficial de RENAPER para cotejo biométrico minucioso/vectorial.
  /// El puntaje (0-100) es generado estocásticamente y expuesto vía [lastFaceMatchScore]
  /// para ser enviado a /verification/local-result y procesado por el Motor de Riesgo (CU-0023).
  Future<bool> matchWithRenaperTemplate(Face capturedFace) async {
    // Simulamos latencia de red contra RENAPER
    await Future.delayed(const Duration(seconds: 2));

    final randomFraction = Random().nextDouble();

    if (randomFraction > 0.3) { // 70% de chance de éxito
      _failedAttempts = 0;
      // Score alto representativo de coincidencia genuina (82 a 99)
      final matchScore = 82 + (Random().nextDouble() * 17).round();
      _lastFaceMatchScore = matchScore;

      await DatabaseLogService().logEvent(
        'BIOMETRIC_MATCH', 
        'Cotejo facial exitoso contra RENAPER (score: $matchScore%)', 
        'SUCCESS'
      );
      return true;
    } else {
      _failedAttempts++;
      // Score bajo representativo de fracaso (15 a 45)
      final matchScore = 15 + (Random().nextDouble() * 30).round();
      _lastFaceMatchScore = matchScore;
      
      final action = _failedAttempts >= maxFailedAttempts ? 'LOCKED' : 'FAILED';
      
      await DatabaseLogService().logEvent(
        'BIOMETRIC_MATCH_FAILED', 
        'Intento $_failedAttempts fallido de cotejo facial (score: $matchScore%)', 
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
