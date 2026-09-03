import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';

/// Screens 05 & 06 - Privacy and Security Information / Permission Rationale
class PermissionScreen extends StatelessWidget {
  const PermissionScreen({super.key});

  Future<void> _requestCameraPermission(BuildContext context) async {
    final status = await Permission.camera.request();
    if (context.mounted) {
      if (status.isGranted) {
        Navigator.pushReplacementNamed(context, '/dni_capture');
      } else if (status.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El permiso de cámara fue denegado permanentemente. Por favor habilítalo en la configuración.'),
          ),
        );
        openAppSettings();
      } else {
        // Direct transition so DniCaptureScreen can handle fallback or retry prompt
        Navigator.pushReplacementNamed(context, '/dni_capture');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permisos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Acceso a Cámara Requerido',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                'Tu cámara es necesaria para verificar tu identidad. Te guiaremos a través de la captura de tu DNI y un breve escaneo facial.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),
              
              _buildInfoRow(
                context,
                Icons.security,
                'Verificación Segura',
                'Tus datos se procesan de forma segura y encriptada.',
              ),
              const SizedBox(height: DesignTokens.spacing24),
              _buildInfoRow(
                context,
                Icons.delete_outline,
                'Procesamiento Temporal',
                'Los datos biométricos se utilizan solo para esta sesión de verificación.',
              ),
              
              const Spacer(),
              
              PrimaryButton(
                text: 'Permitir Acceso a Cámara',
                onPressed: () => _requestCameraPermission(context),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              TextualButton(
                text: 'Ahora No',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String title, String subtitle) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.primaryColor, size: 28),
        const SizedBox(width: DesignTokens.spacing16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
