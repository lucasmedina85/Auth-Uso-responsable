import "package:flutter/foundation.dart" show kIsWeb;
import "dart:io" as io;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../core/theme/design_tokens.dart';
import '../../logic/face_biometric_service.dart';
import '../../core/network/dio_client.dart';
import 'package:dio/dio.dart';
import 'security_alert_screen.dart';
import 'emulator_blocked_screen.dart';
import '../../services/device_integrity_service.dart';
import '../../services/network_security_service.dart';
import '../../services/behavioral_biometrics_service.dart';
import '../widgets/behavior_tracker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../widgets/buttons.dart';
import '../../core/config/app_config.dart';
import '../../core/database/app_database.dart';
import '../../services/demo_mode_service.dart';
import '../../services/session_service.dart';
import '../widgets/demo_mode_banner.dart';

enum LivenessState { initializing, readyToCapture, awaitingConfirmation, processing, success, failed, error }

/// Screens 22-28 - Facial Biometrics & Liveness
class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  LivenessState _state = LivenessState.initializing;
  String _instruction = "Preparando cámara...";

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  String? _recordedVideoPath;

  final _biometricService = FaceBiometricService();
  bool _isProcessingFrame = false;
  XFile? _capturedImageFile;

  @override
  void initState() {
    super.initState();
    _setupCameraAndStartFlow();
  }

  Future<void> _setupCameraAndStartFlow() async {
    try {
      PermissionStatus status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }

      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _state = LivenessState.error;
            _instruction = "Permiso de cámara denegado. Es obligatorio para continuar.";
          });
        }
        return;
      }
      
      final cameras = await availableCameras().timeout(const Duration(seconds: 3), onTimeout: () {
        throw TimeoutException("No se pudieron obtener las cámaras disponibles.");
      });
      if (cameras.isNotEmpty) {
        final frontCam = cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => cameras.first,
        );

        final controller = CameraController(
          frontCam,
          ResolutionPreset.medium,
          enableAudio: false,
        );

        // Pequeña pausa para asegurar que el hardware esté libre
        await Future.delayed(const Duration(milliseconds: 500));
        
        await controller.initialize().timeout(const Duration(seconds: 5), onTimeout: () {
          throw TimeoutException("La cámara tardó demasiado en iniciar.");
        });
        try {
          await controller.setFlashMode(FlashMode.off);
        } catch (_) {
          // Ignorar si la cámara frontal no soporta flash
        }
        
        if (mounted) {
          setState(() {
            _cameraController = controller;
            _isCameraInitialized = true;
          });
          _prepareForCapture();
        }
      } else {
        if (mounted) {
          setState(() {
            _state = LivenessState.error;
            _instruction = "No se encontró cámara en el dispositivo.";
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _state = LivenessState.error;
          _instruction = "Error al inicializar cámara: $e";
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _biometricService.dispose();
    super.dispose();
  }

  void _prepareForCapture() {
    if (!mounted) return;
    setState(() {
      _capturedImageFile = null;
      _state = LivenessState.readyToCapture;
      _instruction = "Ubique su rostro en el óvalo y presione 'Capturar'";
    });
  }

  void _captureFace() async {
    if (!mounted || _cameraController == null || !_cameraController!.value.isInitialized) return;
    
    setState(() {
      _isProcessingFrame = true;
    });

    try {
      final imageFile = await _cameraController!.takePicture();
      if (mounted) {
        setState(() {
          _capturedImageFile = imageFile;
          _state = LivenessState.awaitingConfirmation;
          _instruction = "¿La captura de tu rostro es nítida y correcta?";
          _isProcessingFrame = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessingFrame = false;
          _instruction = "Error al capturar. Intente de nuevo.";
        });
      }
    }
  }

  void _processLivenessAndMatch() async {
    if (!mounted || _capturedImageFile == null) return;
    
    setState(() {
      _state = LivenessState.processing;
      _instruction = "Analizando liveness...\nCotejando contra RENAPER (1:1)...";
    });

    try {
      final inputImage = InputImage.fromFilePath(_capturedImageFile!.path);
      final face = await _biometricService.checkPassiveLiveness(inputImage);
      
      if (face == null) {
        _showFailedMatch("No se detectó un rostro real válido (Liveness fallido).");
        return;
      }

      // Cotejo 1:1 local contra RENAPER (calcula dinámicamente _lastFaceMatchScore)
      final isMatch = await _biometricService.matchWithRenaperTemplate(face);
      if (!isMatch) {
        final attemptsLeft = FaceBiometricService.maxFailedAttempts - _biometricService.failedAttempts;
        _showFailedMatch("Cotejo Fallido.\nEl rostro no coincide con el DNI.\nIntentos restantes: $attemptsLeft");
        return;
      }

      // CU-0023: Envío de resultados y señales reales al Motor de Riesgo backend
      if (AppConfig.isLocal) {
        final scenario = DemoModeService().currentScenario;

        if (scenario == DemoScenario.SUPLANTACION) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SecurityAlertScreen(
            title: 'Suplantación de Identidad',
            message: 'El sistema ha detectado un intento de fraude biométrico. Su cuenta y dispositivos quedan bajo revisión.',
          )));
          return;
        }

        if (scenario == DemoScenario.DNI_DENUNCIADO) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SecurityAlertScreen(
            title: 'DNI Bloqueado',
            message: 'Este documento ha sido reportado o figura en las listas de denegación. Contacte a la autoridad emisora.',
          )));
          return;
        }

        if (scenario == DemoScenario.BLOQUEO_RIESGO) {
          if (!mounted) return;
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SecurityAlertScreen(
            title: 'Validación Bloqueada por Seguridad',
            message: 'El nivel de riesgo detectado supera los límites permitidos. La sesión ha sido bloqueada.',
          )));
          return;
        }

        if (scenario == DemoScenario.REVISION) {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/verification_review',
            arguments: {
              'decision': 'REVISIÓN',
              'status': 'UNDER_REVIEW',
              'riskScore': 65,
              'factors': ['Horario no habitual detectado', 'Score biométrico intermedio'],
            },
          );
          return;
        }

        // Decisión AUTORIZAR / OK
        final activeEmail = await SessionService.getActiveUserEmail() ?? AppDatabase.demoEmail;
        final user = await AppDatabase().getUserByEmail(activeEmail);
        final userId = user?['id'] ?? AppDatabase.demoUserId;

        await AppDatabase().updateUserStatus(userId, 'LOCALLY_VERIFIED');
        await AppDatabase().logActivity(
          userId: userId,
          type: 'VERIFICATION',
          action: 'Prueba Biométrica Facial',
          description: 'Identidad validada exitosamente con score 96% (Modo Local Offline)',
          severity: 'INFO',
        );

        if (!mounted) return;
        setState(() {
          _state = LivenessState.success;
          _instruction = "¡Identidad Verificada Exitosamente!";
        });
        
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/fingerprint');
        return;
      }

      try {
        final dio = DioClient().dio;
        final clientNetRisk = await NetworkSecurityService.checkVpnAndProxy();
        final behaviorMetrics = BehavioralBiometricsService().getAggregatedMetrics();
        final integrityResult = await DeviceIntegrityService.checkIntegrity();
        
        final response = await dio.post('/verification/local-result', data: {
           'dniHash': 'mocked_hash_from_liveness',
           'emulatorDetected': integrityResult.isEmulator,
           'deviceCompromised': integrityResult.isCompromised,
           'clientVpnDetected': clientNetRisk.isVpn,
           'clientProxyDetected': clientNetRisk.isProxy,
           'behavioralAdultScore': behaviorMetrics.behavioralAdultScore,
           'aggregatedBehaviorMetrics': behaviorMetrics.toMap(),
           'livenessScore': _biometricService.lastLivenessScore,
           'faceMatchScore': _biometricService.lastFaceMatchScore,
           'isLatestDocument': true, // DNI vigente validado en paso previo
           'failedFaceAttempts': _biometricService.failedAttempts,
        });

        final decision = response.data['decision'];
        final status = response.data['status'];

        if (decision == 'REVISIÓN' || status == 'UNDER_REVIEW') {
          if (!mounted) return;
          Navigator.pushReplacementNamed(
            context,
            '/verification_review',
            arguments: response.data,
          );
          return;
        }

        // Decisión AUTORIZAR / OK
        if (!mounted) return;
        setState(() {
          _state = LivenessState.success;
          _instruction = "¡Identidad Verificada Exitosamente!";
        });
        
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) Navigator.pushReplacementNamed(context, '/fingerprint');
        return;

      } on DioException catch (apiError) {
        if (!mounted) return;
        if (apiError.response?.statusCode == 403) {
           final errorCode = apiError.response?.data['errorCode'] ?? '';
           final decision = apiError.response?.data['decision'];
           if (errorCode == 'EMULATOR_DETECTED') {
             Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (ctx) => const EmulatorBlockedScreen()), (route) => false);
             return;
           } else if (errorCode == 'RISK_BLOCKED' || decision == 'BLOQUEAR') {
             Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SecurityAlertScreen(
               title: 'Validación Bloqueada por Seguridad',
               message: 'El nivel de riesgo detectado supera los límites permitidos. La sesión ha sido bloqueada.',
             )));
             return;
           } else if (errorCode == 'SPOOFING_DETECTED') {
             Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SecurityAlertScreen(
               title: 'Suplantación de Identidad',
               message: 'El sistema ha detectado un intento de fraude biométrico. Su cuenta y dispositivos quedan bajo revisión.',
             )));
             return;
           } else if (errorCode == 'DNI_BLOCKED_STOLEN') {
             Navigator.push(context, MaterialPageRoute(builder: (ctx) => const SecurityAlertScreen(
               title: 'DNI Bloqueado',
               message: 'Este documento ha sido reportado o figura en las listas de denegación. Contacte a la autoridad emisora.',
             )));
             return;
           }
        }
        rethrow;
      }
    } catch (e) {
      if (!mounted) return;
      _showFailedMatch(e.toString());
    }
  }

  void _showFailedMatch(String message) {
    setState(() {
      _state = LivenessState.failed;
      _instruction = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BehaviorTracker(
      screenName: 'FaceLivenessScreen',
      child: Scaffold(
        backgroundColor: Colors.black, // Camera backdrop
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Live Camera Feed or Captured Image
            if (_state == LivenessState.awaitingConfirmation && _capturedImageFile != null)
              Positioned.fill(
                child: kIsWeb
                    ? Image.network(_capturedImageFile!.path, fit: BoxFit.cover)
                    : Image.file(io.File(_capturedImageFile!.path), fit: BoxFit.cover),
              )
            else if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
              ),

            // Demo Mode Banner
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: DemoModeBanner(),
            ),

            // Top Header Bar: Video Recording Badge
            Positioned(
              top: 20,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isRecordingVideo ? Icons.fiber_manual_record : Icons.videocam,
                          color: _isRecordingVideo ? Colors.redAccent : Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _isRecordingVideo 
                              ? 'Grabando Video Liveness...' 
                              : (_recordedVideoPath != null ? 'Video Almacenado' : 'Prueba Biométrica'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // 2. Face Guide Oval
            Positioned(
              top: MediaQuery.of(context).size.height * 0.15,
              child: Container(
                width: 250,
                height: 350,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _state == LivenessState.success
                        ? AppColorsLight.success
                        : _state == LivenessState.failed
                            ? theme.colorScheme.error
                            : theme.primaryColor,
                    width: 4,
                  ),
                  borderRadius: const BorderRadius.all(Radius.elliptical(125, 175)),
                  color: Colors.transparent,
                ),
              ),
            ),

            // 3. Status/Instruction Overlay - ALWAYS WHITE TEXT (LETRAS BLANCAS)
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_state == LivenessState.processing)
                      const Padding(
                        padding: EdgeInsets.only(bottom: DesignTokens.spacing16),
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                      
                    if (_state == LivenessState.success)
                      const Padding(
                        padding: EdgeInsets.only(bottom: DesignTokens.spacing16),
                        child: Icon(Icons.check_circle, color: AppColorsLight.success, size: 48),
                      ),

                    const SizedBox(height: DesignTokens.spacing8),
                    
                    // Main Challenge instruction text in WHITE LETTERS (Letras Blancas)
                    Text(
                      _instruction,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        height: 1.3,
                      ),
                    ),

                    if (_recordedVideoPath != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.check, color: AppColorsLight.success, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Video capturado y almacenado en el aplicativo',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    if (_state == LivenessState.readyToCapture) ...[
                      const SizedBox(height: DesignTokens.spacing24),
                      PrimaryButton(
                        text: 'Capturar Rostro',
                        onPressed: _isProcessingFrame ? null : _captureFace,
                        isLoading: _isProcessingFrame,
                      ),
                    ],

                    if (_state == LivenessState.awaitingConfirmation) ...[
                      const SizedBox(height: DesignTokens.spacing24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _prepareForCapture,
                              child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                          const SizedBox(width: DesignTokens.spacing16),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColorsLight.success,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: _processLivenessAndMatch,
                              child: const Text('Sí, es correcta', style: TextStyle(color: Colors.white)),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_state == LivenessState.error) ...[
                      const SizedBox(height: DesignTokens.spacing24),
                      PrimaryButton(
                        text: 'Intentar de Nuevo / Volver',
                        onPressed: () async {
                          if (await Permission.camera.isPermanentlyDenied) {
                            openAppSettings();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                      ),
                    ],

                    if (_state == LivenessState.failed) ...[
                      const SizedBox(height: DesignTokens.spacing24),
                      if (_biometricService.failedAttempts < FaceBiometricService.maxFailedAttempts)
                        PrimaryButton(
                          text: 'Intentar de Nuevo',
                          onPressed: () {
                            _prepareForCapture();
                          },
                        ),
                      const SizedBox(height: DesignTokens.spacing8),
                      TextualButton(
                        text: _biometricService.failedAttempts >= FaceBiometricService.maxFailedAttempts 
                            ? 'Volver al Inicio (Bloqueado)' 
                            : 'Cancelar',
                        onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/splash', (route) => false),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
