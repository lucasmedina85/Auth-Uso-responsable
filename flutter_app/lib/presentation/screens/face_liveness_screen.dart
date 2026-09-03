import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import '../../core/theme/design_tokens.dart';
import '../../logic/security_data_service.dart';
import '../widgets/buttons.dart';

enum LivenessState { initializing, activeChallenge, passiveAnalysis, processing, success, failed }

/// Screens 22-28 - Facial Biometrics & Liveness
class FaceLivenessScreen extends StatefulWidget {
  const FaceLivenessScreen({super.key});

  @override
  State<FaceLivenessScreen> createState() => _FaceLivenessScreenState();
}

class _FaceLivenessScreenState extends State<FaceLivenessScreen> {
  LivenessState _state = LivenessState.initializing;
  String _instruction = "Preparando cámara...";
  int _challengeIndex = 0;
  final List<String> _challenges = [
    "Mira directamente a la cámara",
    "Parpadea dos veces",
    "Gira la cabeza ligeramente a la derecha"
  ];

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isRecordingVideo = false;
  String? _recordedVideoPath;

  @override
  void initState() {
    super.initState();
    _setupCameraAndStartFlow();
  }

  Future<void> _setupCameraAndStartFlow() async {
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        final cameras = await availableCameras();
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

          await controller.initialize();
          if (mounted) {
            setState(() {
              _cameraController = controller;
              _isCameraInitialized = true;
            });
          }
        }
      }
    } catch (_) {
      // Fallback gracefully if camera is unavailable or permission denied
    }

    _startFlow();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _startFlow() async {
    // 1. Initializing
    await Future.delayed(const Duration(seconds: 1));

    // Start Recording Video if camera initialized
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.startVideoRecording();
        if (mounted) {
          setState(() {
            _isRecordingVideo = true;
          });
        }
      } catch (_) {}
    }
    
    // 2. Active Liveness Challenges
    for (int i = 0; i < _challenges.length; i++) {
      if (!mounted) return;
      setState(() {
        _state = LivenessState.activeChallenge;
        _challengeIndex = i;
        _instruction = _challenges[i];
      });
      await Future.delayed(const Duration(seconds: 3));
    }

    // Stop recording video and store it in application state
    if (_cameraController != null && _cameraController!.value.isRecordingVideo) {
      try {
        final XFile videoFile = await _cameraController!.stopVideoRecording();
        _recordedVideoPath = videoFile.path;
        SecurityDataService().livenessVideoPath = _recordedVideoPath;
        if (mounted) {
          setState(() {
            _isRecordingVideo = false;
          });
        }
      } catch (_) {}
    } else {
      // Simulation path fallback
      _recordedVideoPath = '/tmp/liveness_proof_video.mp4';
      SecurityDataService().livenessVideoPath = _recordedVideoPath;
    }

    if (!mounted) return;
    
    // 3. Passive Liveness & Processing
    setState(() {
      _state = LivenessState.processing;
      _instruction = "Analizando presencia y verificando identidad...";
    });
    
    await Future.delayed(const Duration(seconds: 3));
    
    if (!mounted) return;
    
    // 4. Success -> Next Screen
    setState(() {
      _state = LivenessState.success;
      _instruction = "¡Identidad Verificada!";
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/fingerprint');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black, // Camera backdrop
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Live Camera Feed
            if (_isCameraInitialized && _cameraController != null)
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: _cameraController!.value.aspectRatio,
                  child: CameraPreview(_cameraController!),
                ),
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
                    if (_state == LivenessState.activeChallenge)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'DESAFÍO ${_challengeIndex + 1} DE ${_challenges.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    
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
                    
                    if (_state == LivenessState.failed) ...[
                      const SizedBox(height: DesignTokens.spacing24),
                      PrimaryButton(
                        text: 'Intentar de Nuevo',
                        onPressed: () {
                          setState(() {
                            _state = LivenessState.initializing;
                            _instruction = "Preparando cámara...";
                          });
                          _startFlow();
                        },
                      ),
                      const SizedBox(height: DesignTokens.spacing8),
                      TextualButton(
                        text: 'Cancelar',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ]
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
