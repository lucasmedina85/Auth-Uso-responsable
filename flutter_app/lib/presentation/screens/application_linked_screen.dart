import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';

class ApplicationLinkedScreen extends StatelessWidget {
  const ApplicationLinkedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final appName = args?['appName'] ?? 'Aplicación';
    final deviceName = args?['deviceName'] ?? 'Dispositivo';

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Success Illustration
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColorsLight.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check,
                      size: 64,
                      color: AppColorsLight.success,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              Text(
                'Aplicación vinculada correctamente',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              Text(
                'Tu dispositivo ya puede generar códigos temporales para esta aplicación.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              // App Details Info
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Aplicación', appName),
                    const Divider(height: 24),
                    _buildInfoRow(context, 'Dispositivo', deviceName),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context, 
                      'Estado', 
                      'Activo', 
                      valueColor: AppColorsLight.success,
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              PrimaryButton(
                text: 'Ver código',
                onPressed: () {
                  // Pass the created app info to the dashboard
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/authenticator_dashboard', 
                    (route) => false,
                    arguments: {
                      'appName': appName,
                      'deviceName': deviceName,
                    }
                  );
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              SecondaryButton(
                text: 'Volver al inicio',
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
