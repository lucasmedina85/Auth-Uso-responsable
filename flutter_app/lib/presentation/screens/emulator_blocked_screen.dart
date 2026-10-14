import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/design_tokens.dart';
import '../../services/emulator_detection_service.dart';

/// Screen de Bloqueo por Detección de Emulador (CU-0034).
///
/// Postcondición: Sesión de validación bloqueada desde el origen.
/// No permite volver atrás ni continuar con ningún flujo de autenticación o validación.
class EmulatorBlockedScreen extends StatelessWidget {
  final List<String>? reasons;

  const EmulatorBlockedScreen({
    super.key,
    this.reasons,
  });

  @override
  Widget build(BuildContext context) {
    final activeReasons = reasons ?? EmulatorDetectionService.lastResult?.reasons ?? [];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A1A1A),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                const Center(
                  child: Icon(
                    Icons.phonelink_erase_rounded,
                    size: 96,
                    color: Color(0xFFEF4444),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing24),
                const Text(
                  'Entorno No Permitido',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing16),
                const Text(
                  'Se ha detectado la ejecución en un emulador o entorno virtualizado (CU-0034).\n\n'
                  'Por normativas de integridad, biometría y prevención de fraude en el Juego Responsable, '
                  'esta aplicación requiere un dispositivo móvil físico genuino.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFF9CA3AF),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                if (activeReasons.isNotEmpty) ...[
                  const SizedBox(height: DesignTokens.spacing24),
                  Container(
                    padding: const EdgeInsets.all(DesignTokens.spacing12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF262626),
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                      border: Border.all(color: const Color(0xFF404040)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Detalles de Integridad:',
                          style: TextStyle(
                            color: Color(0xFFE5E7EB),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ...activeReasons.take(3).map(
                              (r) => Text(
                                '• $r',
                                style: const TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 11,
                                ),
                              ),
                            ),
                      ],
                    ),
                  ),
                ],
                const Spacer(),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                    ),
                  ),
                  icon: const Icon(Icons.exit_to_app),
                  onPressed: () {
                    SystemNavigator.pop();
                  },
                  label: const Text(
                    'Cerrar Aplicación',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
