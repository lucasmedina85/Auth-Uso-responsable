import 'dart:async';
import 'dart:io' as io;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/design_tokens.dart';
import '../../logic/security_data_service.dart';
import '../../logic/ocr_processor.dart';
import '../../logic/document_validator.dart';
import '../../logic/age_calculator.dart';
import '../widgets/buttons.dart';
import 'package:intl/intl.dart';
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

  final OcrProcessor _ocrProcessor = OcrProcessor();
  final AgeCalculator _ageCalculator = AgeCalculator();
  final DocumentValidator _docValidator = DocumentValidator();
  int _ocrFailures = 0;
  DniBiographicData? _scannedData;

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
      PermissionStatus permissionStatus = await Permission.camera.status;
      if (!permissionStatus.isGranted) {
        permissionStatus = await Permission.camera.request();
      }

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

      final cameras = await availableCameras().timeout(const Duration(seconds: 3), onTimeout: () {
        throw TimeoutException("No se pudieron obtener las cámaras disponibles.");
      });
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

      await controller.initialize().timeout(const Duration(seconds: 5), onTimeout: () {
        throw TimeoutException("La cámara tardó demasiado en iniciar.");
      });
      try {
        await controller.setFlashMode(FlashMode.off);
      } catch (_) {
        // Ignore if flash is not supported
      }

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
          _cameraErrorMessage = 'Error fatal de hardware al acceder a la cámara: ${e.toString()}';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _ocrProcessor.dispose();
    super.dispose();
  }

  Future<void> _cleanupAndNavigate(VoidCallback action) async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
    // Pequeña pausa extra para que Android termine de liberar el hardware de la cámara
    await Future.delayed(const Duration(milliseconds: 500));
    action();
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
          _cameraErrorMessage = 'Fallo crítico en hardware de cámara: ${e.toString()}';
        });
        _cameraController?.dispose();
        _cameraController = null;
        _isCameraInitialized = false;
      }
    }
  }

  void _handleValidation(bool isAccepted) async {
    if (!isAccepted) {
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
      return;
    }

    setState(() => _isProcessing = true);

    if (_step == FlutterCaptureStep.validateFront) {
      final data = await _ocrProcessor.processFrontImage(_frontPath!);
      if (mounted) setState(() => _isProcessing = false);

      if (data != null) {
        _ocrFailures = 0;
        _scannedData = data; // Guardar datos PDF417 (Frente)
        if (mounted) setState(() => _step = FlutterCaptureStep.back);
      } else {
        _ocrFailures++;
        if (_ocrFailures >= 3) {
          _ocrFailures = 0; // Reset for back step
          if (mounted) setState(() => _step = FlutterCaptureStep.back);
        } else {
          _showErrorSnackBar('No pudimos leer el código de barras. Intentá nuevamente (${3 - _ocrFailures} intentos restantes).');
          if (mounted) {
            setState(() {
              _frontPath = null;
              _step = FlutterCaptureStep.front;
            });
          }
        }
      }
    } else if (_step == FlutterCaptureStep.validateBack) {
      final backData = await _ocrProcessor.processBackImage(_backPath!);
      if (mounted) setState(() => _isProcessing = false);

      // Combinar datos del frente (PDF417) y dorso (MRZ)
      // Si alguno falló, usamos el otro. Priorizamos el frente porque PDF417 suele tener nombres completos
      DniBiographicData? data = _scannedData ?? backData;

      if (data != null) {
        // Enriquecer con número de trámite del MRZ si PDF417 no lo trajo, o viceversa
        if (backData != null && data.tramitNumber == null) {
          data = data.copyWith(tramitNumber: backData.tramitNumber);
        }
        
        // CU-0006: Detección de manipulación simulada (Si el DNI contiene muchos ceros o falla un hash)
        if (data.documentNumber == "00000000" || data.documentNumber.contains("123456")) {
          _showBlockingDialog(
            title: 'Manipulación Detectada',
            message: 'Se ha detectado una posible manipulación o falsificación en el código PDF417 del documento. Se bloqueó la autenticación.',
            icon: Icons.gpp_bad,
          );
          return;
        }

        // CU-0005: Validación de vigencia (mostrar fechas)
        if (!_docValidator.isDocumentValid(data.expirationDate)) {
          final nowFormat = DateFormat('dd/MM/yyyy').format(DateTime.now());
          final expFormat = DateFormat('dd/MM/yyyy').format(data.expirationDate);
          
          _showBlockingDialog(
            title: 'Documento Vencido',
            message: 'La fecha de vigencia de tu DNI ($expFormat) es menor a la fecha actual ($nowFormat). No se permite continuar.',
            icon: Icons.event_busy,
          );
          return;
        }

        if (!_ageCalculator.isAdult(data.birthDate)) {
          final birthFormat = DateFormat('dd/MM/yyyy').format(data.birthDate);
          _showBlockingDialog(
            title: 'Acceso Denegado',
            message: 'La fecha de nacimiento ($birthFormat) indica que el titular es menor de 18 años. Solo los mayores de edad pueden utilizar la aplicación (CU-0007).',
            icon: Icons.block,
          );
          return;
        }

        // CU-0003 y CU-0004: Mostrar datos extraídos y pedir confirmación
        _showDataConfirmationDialog(data);

      } else {
        _ocrFailures++;
        if (_ocrFailures >= 3) {
          _cleanupAndNavigate(() => widget.onManualFallback());
        } else {
          _showErrorSnackBar('No pudimos leer los datos del reverso. Intentá nuevamente (${3 - _ocrFailures} intentos restantes).');
          if (mounted) {
            setState(() {
              _backPath = null;
              _step = FlutterCaptureStep.back;
            });
          }
        }
      }
    }
  }

  void _showBlockingDialog({required String title, required String message, required IconData icon}) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              // Reset the flow on block, or navigate back
              setState(() {
                _backPath = null;
                _step = FlutterCaptureStep.back;
              });
            },
            child: const Text('Entendido', style: TextStyle(color: AppColorsLight.primary)),
          )
        ],
      ),
    );
  }

  void _showDataConfirmationDialog(DniBiographicData data) {
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false, // Must select an option
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black87,
        title: const Text('Confirmar Datos Extraídos', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Verificá que los datos leídos del DNI sean correctos:\n', style: TextStyle(color: Colors.white70)),
              _buildDataRow('Apellido', data.lastName),
              _buildDataRow('Nombre', data.firstName),
              _buildDataRow('DNI', data.documentNumber),
              _buildDataRow('Sexo', data.gender),
              _buildDataRow('Fecha de Nac.', DateFormat('dd/MM/yyyy').format(data.birthDate)),
              if (data.tramitNumber != null) 
                _buildDataRow('Trámite', data.tramitNumber!),
              _buildDataRow('Vigencia', DateFormat('dd/MM/yyyy').format(data.expirationDate)),
              const SizedBox(height: 16),
              if (_ageCalculator.isAdult(data.birthDate) && _docValidator.isDocumentValid(data.expirationDate))
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.green.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Es mayor de edad y el documento está vigente.', style: TextStyle(color: Colors.green, fontSize: 13))),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              const Text('¿Son correctos los datos?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _cleanupAndNavigate(() => widget.onManualFallback());
            },
            child: const Text('No, ingresar manual', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColorsLight.success),
            onPressed: () {
              Navigator.of(ctx).pop();
              // CU-0003: User confirms data
              _cleanupAndNavigate(() => widget.onComplete(_frontPath!, _backPath!));
            },
            child: const Text('Sí, son correctos', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Widget _buildDataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70)),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
        duration: const Duration(seconds: 4),
      ),
    );
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
                  text: 'Reintentar Acceso a Cámara',
                  onPressed: _initializeCameraWithPermission,
                  isLoading: _isProcessing,
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
                  onPressed: () => _cleanupAndNavigate(widget.onManualFallback),
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

