import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';

class MandatoryUpdateScreen extends StatelessWidget {
  final String currentVersion;
  final String minimumRequiredVersion;
  final VoidCallback onUpdatePressed;

  const MandatoryUpdateScreen({
    super.key,
    this.currentVersion = '1.0.0',
    this.minimumRequiredVersion = '1.2.0',
    required this.onUpdatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Security Warning Header Icon
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColorsLight.warning.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update,
                    size: 48,
                    color: AppColorsLight.warning,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Title
              Text(
                'Actualización Obligatoria',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),

              // Description Body
              Text(
                'Se ha detectado una versión obsoleta de la aplicación (v$currentVersion). Para garantizar la máxima seguridad en la validación de identidad y el cumplimiento normativo de Juego Responsable, es necesario actualizar a la versión $minimumRequiredVersion o superior.\n\nFecha límite: 02/09/2026',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Security Info Card
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.shield_outlined,
                      color: theme.primaryColor,
                      size: 28,
                    ),
                    const SizedBox(width: DesignTokens.spacing16),
                    Expanded(
                      child: Text(
                        'Versión de Android. Protección de datos y cifrado actualizados.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spacing48),

              // Primary Action Button
              PrimaryButton(
                text: 'ACTUALIZAR (GOOGLE PLAY)',
                onPressed: onUpdatePressed,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
