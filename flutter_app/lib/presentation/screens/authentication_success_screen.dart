import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/totp_components.dart';

class AuthenticationSuccessScreen extends StatelessWidget {
  const AuthenticationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Header
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColorsLight.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined, // Shield icon as requested
                      size: 48,
                      color: AppColorsLight.success,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              Text(
                'Identidad verificada',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing8),
              
              Text(
                'Tu identidad fue validada correctamente.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              // Authenticator Section
              Text(
                'Authenticator',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing8),
              
              Text(
                'Generá códigos temporales para acceder de forma segura a tus aplicaciones autorizadas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              // Demo Application Card
              ApplicationCard(
                appName: 'Mi Autenticador',
                deviceName: 'Este dispositivo',
                applicationId: 'demo_app',
                onCopy: () {
                  // Handled internally by ApplicationCard
                },
                onMenuTap: () {},
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              // Add Application Button
              PrimaryButton(
                text: '+ Agregar aplicación',
                onPressed: () {
                  Navigator.pushNamed(context, '/add_application');
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              // Skip / Go to Dashboard
              SecondaryButton(
                text: 'Ir al Inicio',
                onPressed: () {
                  // Navigate to user dashboard, clear stack
                  Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
