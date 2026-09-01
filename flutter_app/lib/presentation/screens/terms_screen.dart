import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Términos y Condiciones'),
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
                'Términos y Condiciones',
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
                '1. OBJETO Y ALCANCE DEL SERVICIO',
                'AUTHENTICATOR es una plataforma tecnológica orientada a facilitar procesos de autenticación, verificación de identidad y validación de seguridad digital.\n\n'
                'La aplicación permite, según las funcionalidades habilitadas:\n'
                '• Crear y administrar una cuenta de usuario.\n'
                '• Realizar procesos de verificación de identidad.\n'
                '• Capturar documentación de identidad.\n'
                '• Procesar información mediante tecnologías de reconocimiento óptico de caracteres.\n'
                '• Realizar validaciones biométricas cuando correspondan.\n'
                '• Aplicar mecanismos de detección de vida.\n'
                '• Evaluar condiciones de seguridad del dispositivo y de la sesión.\n'
                '• Generar evidencias y registros de auditoría.\n'
                '• Integrarse con servicios externos autorizados para procesos de validación.\n\n'
                'El acceso y utilización de AUTHENTICATOR implica la aceptación de estos Términos y Condiciones y de la Política de Privacidad aplicable.'
              ),
              
              _buildSection(
                context,
                '2. ACEPTACIÓN DE LOS TÉRMINOS',
                'La utilización de la aplicación implica que la persona usuaria ha leído, comprendido y aceptado los presentes Términos y Condiciones.\n\n'
                'Si la persona usuaria no acepta estos términos, no deberá continuar con el proceso de registro ni utilizar las funcionalidades que requieran dicho consentimiento.'
              ),

              _buildSection(
                context,
                '3. USO ADECUADO DE LA PLATAFORMA',
                'La persona usuaria se compromete a utilizar AUTHENTICATOR de forma lícita, responsable y conforme a la legislación aplicable.\n\n'
                'Queda prohibido:\n'
                '• Intentar suplantar la identidad de otra persona.\n'
                '• Utilizar fotografías, videos, pantallas o documentos falsificados para superar procesos biométricos.\n'
                '• Alterar o manipular documentación.\n'
                '• Intentar vulnerar mecanismos de seguridad.\n'
                '• Utilizar software destinado a interferir con el funcionamiento de la aplicación.\n'
                '• Utilizar dispositivos comprometidos cuando ello afecte la integridad del proceso.\n'
                '• Intentar acceder a información de terceros sin autorización.\n\n'
                'Los intentos de fraude podrán provocar la interrupción inmediata del proceso y la generación de registros de seguridad y auditoría.'
              ),

              _buildSection(
                context,
                '4. VERACIDAD DE LA INFORMACIÓN',
                'La persona usuaria declara que la información proporcionada durante los procesos de registro y verificación es verdadera, correcta y actualizada.\n\n'
                'La utilización de información falsa, adulterada o perteneciente a terceros podrá provocar:\n'
                '• Rechazo de la verificación.\n'
                '• Bloqueo temporal o permanente del acceso.\n'
                '• Generación de alertas de seguridad.\n'
                '• Aplicación de los procedimientos correspondientes conforme a la normativa aplicable.'
              ),

              _buildSection(
                context,
                '5. DISPONIBILIDAD DEL SERVICIO',
                'AUTHENTICATOR podrá depender de servicios tecnológicos internos y externos.\n\n'
                'La disponibilidad de determinadas funcionalidades puede verse afectada temporalmente por:\n'
                '• Mantenimiento.\n'
                '• Actualizaciones.\n'
                '• Problemas de conectividad.\n'
                '• Fallas de servicios externos.\n'
                '• Problemas de infraestructura.\n\n'
                'Cuando una verificación oficial o crítica no pueda completarse de manera segura, el sistema deberá priorizar la seguridad y podrá impedir temporalmente la finalización del proceso.'
              ),

              _buildSection(
                context,
                '6. SEGURIDAD DE LA CUENTA',
                'La persona usuaria es responsable de mantener la confidencialidad de sus credenciales de acceso.\n\n'
                'Se recomienda:\n'
                '• No compartir contraseñas.\n'
                '• Utilizar mecanismos de seguridad del dispositivo.\n'
                '• Mantener la aplicación actualizada.\n'
                '• Informar cualquier actividad sospechosa.\n'
                '• No permitir el acceso de terceros a una sesión autenticada.'
              ),

              _buildSection(
                context,
                '7. MODIFICACIONES',
                'AUTHENTICATOR podrá actualizar estos Términos y Condiciones cuando sea necesario.\n\n'
                'Cuando corresponda una aceptación adicional debido a cambios relevantes, la aplicación deberá solicitar nuevamente el consentimiento de la persona usuaria antes de continuar utilizando determinadas funcionalidades.'
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
