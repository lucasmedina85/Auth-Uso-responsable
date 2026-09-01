import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
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

  void _handleCapture() async {
    setState(() {
      _isProcessing = true;
    });
    
    // Simulate camera capture delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
        if (_step == FlutterCaptureStep.front) {
          _frontPath = '/tmp/dni_front_flutter.jpg';
          _step = FlutterCaptureStep.validateFront;
        } else if (_step == FlutterCaptureStep.back) {
          _backPath = '/tmp/dni_back_flutter.jpg';
          _step = FlutterCaptureStep.validateBack;
        }
      });
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isValidationStep = _step == FlutterCaptureStep.validateFront || _step == FlutterCaptureStep.validateBack;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _step == FlutterCaptureStep.front || _step == FlutterCaptureStep.validateFront
              ? 'DNI Frente'
              : _step == FlutterCaptureStep.back || _step == FlutterCaptureStep.validateBack
                  ? 'DNI Reverso'
                  : 'Error de Cámara',
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
                            ? 'Ahora volteá tu DNI para capturar el código de barras.'
                            : 'El hardware de la cámara no está disponible.',
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
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline_rounded,
                              size: 64,
                              color: theme.colorScheme.error,
                            ),
                            const SizedBox(height: DesignTokens.spacing16),
                            Text(
                              'Fallo en Acceso a Cámara',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.white,
                              ),
                            ),
                          ],
                        )
                      else ...[
                        // Argentine DNI Frame Ratio (8.56cm x 5.398cm ~ 1.586)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: AspectRatio(
                            aspectRatio: 1.586,
                            child: Container(
                              decoration: BoxDecoration(
                                color: isValidationStep ? Colors.grey.shade800 : Colors.transparent,
                                border: Border.all(
                                  color: isValidationStep ? Colors.white : theme.primaryColor,
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: isValidationStep
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.image_outlined,
                                            size: 48,
                                            color: Colors.white.withOpacity(0.5),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Captura Realizada',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              color: Colors.white,
                                            ),
                                          )
                                        ],
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        
                        if (!isValidationStep)
                          Positioned(
                            bottom: 30,
                            child: Text(
                              _step == FlutterCaptureStep.front
                                  ? 'LADO FRONTAL'
                                  : 'LADO TRASERO (PDF417)',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white.withOpacity(0.8),
                                letterSpacing: 1.5,
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
              const SizedBox(height: DesignTokens.spacing32),

              // Checklist for Front Step (Only when not validating)
              if (_step == FlutterCaptureStep.front && !_isProcessing) ...[
                _buildChecklistItem(context, 'Buena iluminación'),
                _buildChecklistItem(context, 'Documento completo visible'),
                _buildChecklistItem(context, 'Sin reflejos'),
                const SizedBox(height: DesignTokens.spacing32),
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
              ] else if (_step != FlutterCaptureStep.cameraError) ...[
                PrimaryButton(
                  text: _step == FlutterCaptureStep.front ? 'Capturar Frente' : 'Capturar Reverso',
                  onPressed: _isProcessing ? null : _handleCapture,
                  isLoading: _isProcessing,
                ),
              ],
              
              const SizedBox(height: DesignTokens.spacing16),

              if (!isValidationStep && (_step == FlutterCaptureStep.cameraError || _step == FlutterCaptureStep.back))
                TextualButton(
                  text: 'Ingresar Datos Manualmente',
                  onPressed: widget.onManualFallback,
                ),
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
          Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
