import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';

class BiometricFingerprintScreen extends StatefulWidget {
  // Keeping the original callbacks to preserve architecture
  final VoidCallback? onSuccess;
  final Function(String error)? onError;

  const BiometricFingerprintScreen({
    super.key,
    this.onSuccess,
    this.onError,
  });

  @override
  State<BiometricFingerprintScreen> createState() => _BiometricFingerprintScreenState();
}

class _BiometricFingerprintScreenState extends State<BiometricFingerprintScreen> with SingleTickerProviderStateMixin {
  bool _isScanning = false;
  bool _isSuccess = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _startScan() async {
    setState(() {
      _isScanning = true;
    });

    // Simulate scanning delay (Native BiometricPrompt Callback)
    await Future.delayed(const Duration(seconds: 3));

    if (mounted) {
      setState(() {
        _isScanning = false;
        _isSuccess = true;
      });

      // Navigate to success after a brief pause
      await Future.delayed(const Duration(milliseconds: 1000));
      if (mounted) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.pushReplacementNamed(context, '/authentication_success');
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Huella Dactilar'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Captura Huella Dactilar',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                _isSuccess 
                    ? 'Huella capturada exitosamente.'
                    : 'Colocá tu dedo sobre el sensor para completar la validación biométrica.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: _isScanning || _isSuccess ? null : _startScan,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isSuccess 
                            ? AppColorsLight.success.withOpacity(0.1)
                            : theme.primaryColor.withOpacity(0.05),
                        border: Border.all(
                          color: _isSuccess 
                              ? AppColorsLight.success 
                              : theme.primaryColor.withOpacity(0.3),
                          width: 2,
                        ),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            _isSuccess ? Icons.fingerprint : Icons.fingerprint_rounded,
                            size: 100,
                            color: _isSuccess 
                                ? AppColorsLight.success
                                : theme.primaryColor.withOpacity(_isScanning ? 0.5 : 1.0),
                          ),
                          if (_isScanning)
                            AnimatedBuilder(
                              animation: _animationController,
                              builder: (context, child) {
                                return Positioned(
                                  top: 50 + (100 * _animationController.value),
                                  child: Container(
                                    width: 120,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme.primaryColor,
                                      boxShadow: [
                                        BoxShadow(
                                          color: theme.primaryColor.withOpacity(0.5),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              if (!_isScanning && !_isSuccess)
                PrimaryButton(
                  text: 'Iniciar Escaneo',
                  onPressed: _startScan,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
