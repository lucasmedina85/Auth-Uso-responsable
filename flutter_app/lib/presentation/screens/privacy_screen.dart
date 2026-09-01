import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Política de Privacidad'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Política de Privacidad y Protección de Datos',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Última actualización: 12 de Agosto de 2026',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),
              
              _buildSection(
                context,
                '1. PRINCIPIOS DE PRIVACIDAD',
                'AUTHENTICATOR reconoce la importancia de la protección de la información personal y aplica principios de:\n\n'
                '• Seguridad.\n'
                '• Minimización de datos.\n'
                '• Finalidad específica.\n'
                '• Transparencia.\n'
                '• Confidencialidad.\n'
                '• Acceso controlado.'
              ),
              
              _buildSection(
                context,
                '2. INFORMACIÓN QUE PUEDE SER TRATADA',
                'Dependiendo de las funcionalidades utilizadas, la plataforma podrá procesar información como:\n\n'
                'Datos de cuenta\n'
                '• Nombre.\n'
                '• Apellido.\n'
                '• Correo electrónico.\n\n'
                'Datos de identidad\n'
                'Cuando el proceso de verificación lo requiera:\n'
                '• Información contenida en documentación presentada.\n'
                '• Datos necesarios para validar identidad.\n\n'
                'Información biométrica\n'
                'Cuando exista consentimiento y fundamento legal aplicable:\n'
                '• Información necesaria para procesos de reconocimiento facial.\n'
                '• Resultados de verificaciones biométricas.\n'
                '• Resultados de pruebas de detección de vida.\n\n'
                'La aplicación debe comunicar claramente qué información es necesaria antes de iniciar cada proceso.'
              ),

              _buildSection(
                context,
                '3. FINALIDAD DEL TRATAMIENTO',
                'La información podrá ser utilizada exclusivamente para finalidades relacionadas con:\n\n'
                '• Registro y autenticación.\n'
                '• Verificación de identidad.\n'
                '• Prevención de fraude.\n'
                '• Protección de cuentas.\n'
                '• Cumplimiento de obligaciones legales aplicables.\n'
                '• Auditoría y seguridad.\n'
                '• Mejora técnica y operativa del servicio.\n\n'
                'No utilizar información personal para finalidades incompatibles con aquellas informadas a la persona usuaria.'
              ),

              _buildSection(
                context,
                '4. INFORMACIÓN BIOMÉTRICA Y SEGURIDAD',
                'La información biométrica requiere un tratamiento especialmente protegido.\n\n'
                'El sistema debe aplicar mecanismos adecuados de seguridad y minimizar la persistencia de información sensible.\n'
                'Cuando el diseño técnico lo permita:\n'
                '• Evitar almacenar imágenes biométricas innecesariamente.\n'
                '• Utilizar procesamiento temporal.\n'
                '• Aplicar cifrado.\n'
                '• Utilizar identificadores anonimizados.\n'
                '• Restringir el acceso mediante controles de autorización.'
              ),

              _buildSection(
                context,
                '5. DATOS DE DISPOSITIVO Y SEGURIDAD',
                'La aplicación podrá procesar información técnica necesaria para proteger la integridad del proceso, como:\n\n'
                '• Tipo de dispositivo.\n'
                '• Versión de la aplicación.\n'
                '• Estado de seguridad del dispositivo.\n'
                '• Eventos de autenticación.\n'
                '• Información técnica de sesión.\n'
                '• Información de red cuando sea necesaria para prevenir fraude.\n\n'
                'La recopilación debe limitarse a lo necesario para la finalidad de seguridad correspondiente.'
              ),

              _buildSection(
                context,
                '6. UBICACIÓN',
                'Cuando una funcionalidad requiera información de ubicación, la aplicación deberá:\n\n'
                '• Solicitar el permiso correspondiente.\n'
                '• Explicar claramente su finalidad.\n'
                '• Permitir conocer cuándo se utiliza.\n'
                '• Continuar sin ubicación cuando la funcionalidad permita una alternativa segura.\n\n'
                'La ubicación no debe solicitarse innecesariamente.'
              ),

              _buildSection(
                context,
                '7. CONSERVACIÓN DE LA INFORMACIÓN',
                'La información deberá conservarse únicamente durante el tiempo necesario para:\n\n'
                '• Cumplir la finalidad informada.\n'
                '• Cumplir obligaciones legales.\n'
                '• Resolver incidentes de seguridad.\n'
                '• Mantener registros de auditoría cuando corresponda.'
              ),

              _buildSection(
                context,
                '8. SEGURIDAD',
                'AUTHENTICATOR deberá implementar medidas razonables de seguridad para proteger la información contra:\n\n'
                '• Acceso no autorizado.\n'
                '• Alteración.\n'
                '• Pérdida.\n'
                '• Divulgación indebida.\n'
                '• Uso fraudulento.\n\n'
                'Las comunicaciones con servicios externos autorizados deberán utilizar mecanismos de protección adecuados.'
              ),

              _buildSection(
                context,
                '9. DERECHOS DE LAS PERSONAS USUARIAS',
                'Las personas usuarias podrán ejercer los derechos que correspondan conforme a la legislación aplicable respecto de sus datos personales.\n\n'
                'La interfaz debe prever una futura sección de:\n'
                'Privacidad y Mis Datos\n'
                'Con opciones para:\n'
                '• Consultar información.\n'
                '• Solicitar actualización.\n'
                '• Solicitar rectificación.\n'
                '• Gestionar consentimientos.\n'
                '• Consultar información sobre el tratamiento.'
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    final theme = Theme.of(context);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacing32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.primaryColor,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing12),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ],
      ),
    );
  }
}
