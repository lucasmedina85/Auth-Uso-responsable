import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

/// Pantalla de Revisión Manual de Validación (CU-0023).
///
/// Se presenta cuando el Motor de Riesgo evalúa la sesión con decisión "REVISIÓN"
/// (Risk Score compuesto entre 50 y 79).
/// Provee al usuario una explicación clara y tranquilizadora, tiempos estimados (24-48h hábiles),
/// y opciones accionables sin exponer tecnicismos ni datos sensibles (PII).
class VerificationReviewScreen extends StatelessWidget {
  final Map<String, dynamic>? reviewData;

  const VerificationReviewScreen({
    super.key,
    this.reviewData,
  });

  @override
  Widget build(BuildContext context) {
    final args = reviewData ??
        (ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?);

    final riskScore = args?['riskScore'];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: const Color(0xFF18181B), // Zinc-900 neutral dark
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: DesignTokens.spacing24,
              vertical: DesignTokens.spacing16,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                // Icono de estado en revisión
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(DesignTokens.spacing24),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.hourglass_top_rounded,
                      size: 72,
                      color: Color(0xFFF59E0B), // Amber-500
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing24),
                const Text(
                  'Validación en Revisión',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing12),
                const Text(
                  'Tu solicitud requiere una verificación complementaria por parte de nuestro equipo de seguridad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Color(0xFFE4E4E7),
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing20),

                // Tarjeta informativa con plazos y recomendaciones
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF3F3F46),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 18,
                            color: Color(0xFFF59E0B),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Información Importante',
                            style: TextStyle(
                              color: Color(0xFFF59E0B),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '• Plazo estimado: 24 a 48 horas hábiles.\n'
                        '• No es necesario que vuelvas a cargar tus fotos o documentos ahora.\n'
                        '• Te notificaremos una vez concluida la revisión.',
                        style: TextStyle(
                          color: Color(0xFFA1A1AA),
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                      if (riskScore != null) ...[
                        const Divider(
                          color: Color(0xFF3F3F46),
                          height: 20,
                        ),
                        Text(
                          'Código de referencia: REF-${riskScore.toString().padLeft(3, '0')}',
                          style: const TextStyle(
                            color: Color(0xFF71717A),
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const Spacer(),

                // Acciones
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF59E0B),
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/home',
                      (route) => false,
                    );
                  },
                  child: const Text(
                    'Entendido / Volver al Inicio',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: DesignTokens.spacing8),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFA1A1AA),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  },
                  child: const Text('Cerrar Sesión'),
                ),
                const SizedBox(height: DesignTokens.spacing8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
