import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/design_tokens.dart';
import '../../logic/security_data_service.dart';
import '../widgets/buttons.dart';

enum FlutterCaptureStep { front, validateFront, back, validateBack, cameraError }

/// Screens 07-12 - DNI Capture Flow
class DniCaptureScreenFlutter extends StatefulWidget {
  final Function(String frontPath, String backPath) onComplete;
  final VoidCallback onManualFallback;

  const DniCaptureScreenFlutter({
    super.key,
    required this.onComplete,
    required this.onManualFallback,
  });

  @override
  State<DniCaptureScreenFlutter> createState() => _DniCaptureScreenFlutterState();
}

class _DniCaptureScreenFlutterState extends State<DniCaptureScreenFlutter> {
  FlutterCaptureStep _step = FlutterCaptureStep.front;
  String? _frontPath;
  String? _backPath;
  bool _isProcessing = false;

  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  String? _cameraErrorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCameraWithPermission();
  }

  Future<void> _initializeCameraWithPermission() async {
    setState(() {
      _isProcessing = true;
      _cameraErrorMessage = null;
    });

    try {
      final permissionStatus = await Permission.camera.request();

      if (!permissionStatus.isGranted) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _step = FlutterCaptureStep.cameraError;
            _cameraErrorMessage = 'Permiso de cámara denegado. Habilítalo para tomar la fotografía.';
          });
        }
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _step = FlutterCaptureStep.cameraError;
            _cameraErrorMessage = 'No se encontró hardware de cámara en el dispositivo.';
          });
        }
        return;
      }

      final selectedCamera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();

      if (mounted) {
        setState(() {
          _cameraController = controller;
          _isCameraInitialized = true;
          _isProcessing = false;
          if (_step == FlutterCaptureStep.cameraError) {
            _step = FlutterCaptureStep.front;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isCameraInitialized = false;
          _step = FlutterCaptureStep.cameraError;
          _cameraErrorMessage = 'Error al acceder a la cámara: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  void _handleCapture() async {
    setState(() {
      _isProcessing = true;
    });

    try {
      String capturedPath;
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile imageFile = await _cameraController!.takePicture();
        capturedPath = imageFile.path;
      } else {
        await Future.delayed(const Duration(milliseconds: 800));
        capturedPath = _step == FlutterCaptureStep.front
            ? '/tmp/dni_front_flutter.jpg'
            : '/tmp/dni_back_flutter.jpg';
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
          if (_step == FlutterCaptureStep.front) {
            _frontPath = capturedPath;
            SecurityDataService().dniFrontPath = capturedPath;
            _step = FlutterCaptureStep.validateFront;
          } else if (_step == FlutterCaptureStep.back) {
            _backPath = capturedPath;
            SecurityDataService().dniBackPath = capturedPath;
            _step = FlutterCaptureStep.validateBack;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _step = FlutterCaptureStep.cameraError;
          _cameraErrorMessage = 'Fallo en la captura de foto: ${e.toString()}';
        });
      }
    }
  }

  void _handleValidation(bool isAccepted) {
    if (isAccepted) {
      if (_step == FlutterCaptureStep.validateFront) {
        setState(() => _step = FlutterCaptureStep.back);
      } else if (_step == FlutterCaptureStep.validateBack) {
        widget.onComplete(_frontPath!, _backPath!);
      }
    } else {
      // Retake
      if (_step == FlutterCaptureStep.validateFront) {
        setState(() {
          _frontPath = null;
          _step = FlutterCaptureStep.front;
        });
      } else if (_step == FlutterCaptureStep.validateBack) {
        setState(() {
          _backPath = null;
          _step = FlutterCaptureStep.back;
        });
      }
    }
  }

  Widget _buildCapturedPreview(String imagePath) {
    Widget imageWidget;
    if (kIsWeb || imagePath.startsWith('http')) {
      imageWidget = Image.network(imagePath, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _buildFallbackPreview());
    } else if (io.File(imagePath).existsSync()) {
      imageWidget = Image.file(io.File(imagePath), fit: BoxFit.cover);
    } else {
      imageWidget = _buildFallbackPreview();
    }

    return Stack(
      fit: StackFit.expand,
      alignment: Alignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: imageWidget,
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColorsLight.success,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check,
                size: 36,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Foto capturada',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            )
          ],
        ),
      ],
    );
  }

  Widget _buildFallbackPreview() {
    return Container(
      color: Colors.grey.shade900,
      child: Center(
        child: Icon(Icons.badge_outlined, size: 80, color: Colors.grey.shade600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValidationStep = _step == FlutterCaptureStep.validateFront || _step == FlutterCaptureStep.validateBack;
    final currentCapturedPath = _step == FlutterCaptureStep.validateFront ? _frontPath : _backPath;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == FlutterCaptureStep.front || _step == FlutterCaptureStep.validateFront
              ? 'DNI Frente'
              : _step == FlutterCaptureStep.back || _step == FlutterCaptureStep.validateBack
                  ? 'DNI Reverso'
                  : 'Acceso a Cámara',
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            children: [
              // Header Instruction Text
              Text(
                isValidationStep 
                    ? 'Por favor, verificá que la captura sea nítida y legible.'
                    : _step == FlutterCaptureStep.front
                        ? 'Colocá el frente de tu DNI dentro del marco.'
                        : _step == FlutterCaptureStep.back
                            ? 'Ahora volteá tu DNI para capturar el código de barras del reverso.'
                            : 'Se requiere permiso para usar la cámara.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing24),

              // Camera Viewfinder or Validation Preview
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                    border: Border.all(
                      color: _step == FlutterCaptureStep.cameraError
                          ? theme.colorScheme.error
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_step == FlutterCaptureStep.cameraError)
                        Padding(
                          padding: const EdgeInsets.all(DesignTokens.spacing24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.no_photography_outlined,
                                size: 64,
                                color: theme.colorScheme.error,
                              ),
                              const SizedBox(height: DesignTokens.spacing16),
                              Text(
                                'Permiso o Hardware de Cámara No Disponible',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: DesignTokens.spacing8),
                              Text(
                                _cameraErrorMessage ?? 'Por favor autorizá el uso de la cámara en el navegador o dispositivo.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        )
                      else ...[
                        // Live Camera Feed
                        if (_isCameraInitialized && _cameraController != null && !isValidationStep)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                            child: AspectRatio(
                              aspectRatio: _cameraController!.value.aspectRatio,
                              child: CameraPreview(_cameraController!),
                            ),
                          ),

                        // Argentine DNI Frame Overlay (Ratio ~ 1.586)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: AspectRatio(
                            aspectRatio: 1.586,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isValidationStep ? Colors.black : Colors.transparent,
                                border: Border.all(
                                  color: isValidationStep ? AppColorsLight.success : theme.primaryColor,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: isValidationStep && currentCapturedPath != null
                                  ? _buildCapturedPreview(currentCapturedPath)
                                  : null,
                            ),
                          ),
                        ),
                        
                        if (!isValidationStep)
                          Positioned(
                            bottom: 20,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                _step == FlutterCaptureStep.front
                                    ? 'LADO FRONTAL'
                                    : 'LADO TRASERO (PDF417)',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (_isProcessing)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.primaryColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing24),

              // Checklist for Front Step (Only when not validating)
              if (_step == FlutterCaptureStep.front && !_isProcessing) ...[
                _buildChecklistItem(context, 'Buena iluminación'),
                _buildChecklistItem(context, 'Documento completo visible dentro del marco'),
                _buildChecklistItem(context, 'Sin reflejos sobre el plástico'),
                const SizedBox(height: DesignTokens.spacing24),
              ],

              // Control Buttons
              if (isValidationStep) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: theme.colorScheme.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                          ),
                        ),
                        onPressed: _isProcessing ? null : () => _handleValidation(false),
                        child: Text(
                          'Volver a tomar',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: DesignTokens.spacing16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                          ),
                        ),
                        onPressed: _isProcessing ? null : () => _handleValidation(true),
                        child: const Text(
                          'Confirmar',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else if (_step == FlutterCaptureStep.cameraError) ...[
                PrimaryButton(
                  text: 'Solicitar Permiso de Cámara',
                  onPressed: _initializeCameraWithPermission,
                  isLoading: _isProcessing,
                ),
                const SizedBox(height: DesignTokens.spacing12),
                TextualButton(
                  text: 'Ingresar Datos Manualmente',
                  onPressed: widget.onManualFallback,
                ),
              ] else ...[
                PrimaryButton(
                  text: _step == FlutterCaptureStep.front ? 'Capturar Frente' : 'Capturar Reverso',
                  onPressed: _isProcessing ? null : _handleCapture,
                  isLoading: _isProcessing,
                ),
              ],
              
              if (!isValidationStep && _step != FlutterCaptureStep.cameraError) ...[
                const SizedBox(height: DesignTokens.spacing12),
                TextualButton(
                  text: 'Ingresar Datos Manualmente',
                  onPressed: widget.onManualFallback,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacing8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColorsLight.success, size: 20),
          const SizedBox(width: DesignTokens.spacing12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

