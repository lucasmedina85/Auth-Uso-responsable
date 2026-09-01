import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';

class RegistrationSuccessScreen extends StatelessWidget {
  const RegistrationSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing40,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              
              // Success Illustration
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColorsLight.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 80,
                      color: AppColorsLight.success,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing40),
              
              Text(
                'Cuenta creada correctamente',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              Text(
                'Tu cuenta está lista. El siguiente paso es verificar tu identidad para acceder a las funcionalidades que requieren un mayor nivel de seguridad.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const Spacer(),
              
              PrimaryButton(
                text: 'Verificar mi identidad',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dni_capture');
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              SecondaryButton(
                text: 'Más tarde',
                onPressed: () {
                  Navigator.pushReplacementNamed(context, '/dashboard');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
