import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../logic/secure_storage_service.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';
import '../widgets/auth_components.dart';
import '../screens/mandatory_update_screen.dart';

/// Screen 04 - Welcome Screen / Initial Access
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _emailController = TextEditingController();
  bool _isEmailValid = false;
  bool _isCheckingVersion = true;
  String _androidVersion = '';

  @override
  void initState() {
    super.initState();
    _checkAndroidVersion();
  }

  Future<void> _checkAndroidVersion() async {
    try {
      if (!kIsWeb) {
        final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        final AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        // Mock requirement: API level 28 (Android 9) or higher
        if (androidInfo.version.sdkInt < 28) {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MandatoryUpdateScreen(
                  currentVersion: 'Android ${androidInfo.version.release}',
                  minimumRequiredVersion: 'Android 9 (API 28)',
                  onUpdatePressed: () {},
                ),
              ),
            );
            return;
          }
        }
        _androidVersion = androidInfo.version.release;
      } else {
        // Mocking for Web
        _androidVersion = 'Web (Simulado)';
      }
    } catch (e) {
      // Ignore
    }
    // CU-0010: Check if session is already active (5 min local persistence)
    final secureStorage = SecureStorageService();
    final isLoggedIn = await secureStorage.isLoggedIn();
    if (isLoggedIn && mounted) {
      final creds = await secureStorage.getCredentials();
      Navigator.pushReplacementNamed(
        context, 
        '/dashboard', 
        arguments: creds['username'] ?? 'Usuario',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isCheckingVersion = false;
      });
    }
  }

  void _validateEmail(String value) {
    // Simple email validation
    final isValid = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value);
    setState(() {
      _isEmailValid = isValid;
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isCheckingVersion) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(color: theme.primaryColor),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Hero Section
              Center(
                child: Image.asset(
                  theme.brightness == Brightness.dark 
                      ? 'assets/images/auth_dark.png' 
                      : 'assets/images/auth_light.png',
                  width: 120, // Adjusted width for new aspect ratio
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              
              Text(
                'Tu identidad, protegida.',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                'Accedé y verificá tu identidad de forma segura, rápida y confiable.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              // Email Section
              StandardTextField(
                label: 'Correo electrónico',
                hint: 'nombre@ejemplo.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: _validateEmail,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              PrimaryButton(
                text: 'Continuar',
                onPressed: _isEmailValid ? () {
                  // Pass the email to login screen
                  Navigator.pushNamed(
                    context, 
                    '/login', 
                    arguments: _emailController.text.trim(),
                  );
                } : null,
              ),
              
              const AuthDivider(text: 'o continuá con'),
              
              // Google Section
              GoogleSignInButton(
                onPressed: () {
                  // Handle Google Sign In
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              // Registration Card
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Column(
                  children: [
                    Text(
                      '¿Es tu primera vez?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing8),
                    Text(
                      'Creá una cuenta y comenzá a proteger tu identidad digital.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing16),
                    SecondaryButton(
                      text: 'Crear una cuenta',
                      onPressed: () {
                        Navigator.pushNamed(context, '/register');
                      },
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              // Legal Text
              Text(
                'Al continuar, declarás haber leído nuestros ',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/terms');
                    },
                    child: Text(
                      'Términos y Condiciones',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                  Text(
                    ' y nuestra ',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, '/privacy');
                    },
                    child: Text(
                      'Política de Privacidad',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              Text(
                'Versión del dispositivo: $_androidVersion',
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
