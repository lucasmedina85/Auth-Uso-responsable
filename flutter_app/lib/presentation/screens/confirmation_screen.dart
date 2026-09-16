import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Pantalla 4 (Confirmación y Retorno): Pantalla de transición breve que indica
/// el éxito de la operación y ejecuta un retorno programático de vuelta a la Pantalla 2 (Login).
class ConfirmationScreen extends StatelessWidget {
  const ConfirmationScreen({super.key});

  void _returnToLogin(BuildContext context) {
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Icon Container with Validation Green #2E7D32
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.validationGreen.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: AppColors.validationGreen,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title Header
              Text(
                '¡Registro Exitoso!',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 12),

              // Confirmation Message
              Text(
                'Su cuenta ha sido creada correctamente en el ecosistema Authenticator.\n\nYa puede ingresar con sus credenciales para iniciar la verificación biométrica.',
                textAlign: TextAlign.center,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 36),

              // Return Button (Industrial Safety Blue #0288D1, 8px radius)
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _returnToLogin(context),
                  icon: const Icon(Icons.login_rounded, color: Colors.white),
                  label: Text(
                    'VOLVER AL INICIO DE SESIÓN',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
