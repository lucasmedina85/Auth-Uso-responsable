import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/design_tokens.dart';
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

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  void _startFlow() async {
    // 1. Initializing
    await Future.delayed(const Duration(seconds: 2));
    
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
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.black, // Camera backdrop
      body: SafeArea(
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 1. Camera Feed Placeholder (Black bg)
            
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
                  borderRadius: BorderRadius.all(Radius.elliptical(125, 175)),
                  color: Colors.transparent,
                ),
              ),
            ),

            // 3. Status/Instruction Overlay
            Positioned(
              bottom: 40,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                decoration: BoxDecoration(
                  color: (isDark ? AppColorsDark.surface : AppColorsLight.surface).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_state == LivenessState.activeChallenge)
                      Text(
                        'Desafío ${_challengeIndex + 1} de ${_challenges.length}',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: theme.primaryColor,
                          letterSpacing: 1.2,
                        ),
                      ),
                    
                    if (_state == LivenessState.processing)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                        child: CircularProgressIndicator(color: theme.primaryColor),
                      ),
                      
                    if (_state == LivenessState.success)
                      Padding(
                        padding: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                        child: Icon(Icons.check_circle, color: AppColorsLight.success, size: 48),
                      ),

                    const SizedBox(height: DesignTokens.spacing8),
                    
                    Text(
                      _instruction,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
