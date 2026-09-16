import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';
import '../../logic/secure_storage_service.dart';
import '../widgets/inputs.dart';
import '../widgets/auth_components.dart';

/// Screen 05 - Login Screen
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isProcessing = false;
  bool _emailInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_emailInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is String) {
        _emailController.text = args;
      }
      _emailInitialized = true;
    }
  }

  void _handleLogin() async {
    setState(() {
      _isProcessing = true;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    
    // Save credentials to Secure Storage (Opcion A)
    final secureStorage = SecureStorageService();
    await secureStorage.saveCredentials(
      _emailController.text,
      _passwordController.text,
    );

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      // Navigate to dashboard for existing user, passing the email
      Navigator.pushReplacementNamed(
        context, 
        '/dashboard',
        arguments: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : 'Usuario',
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Iniciar sesión',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Ingresá con los datos de tu cuenta para continuar.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              StandardTextField(
                label: 'Correo electrónico',
                hint: 'nombre@ejemplo.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: DesignTokens.spacing24),
              PasswordTextField(
                label: 'Contraseña',
                hint: 'Ingresá tu contraseña',
                controller: _passwordController,
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () {
                    // Forgot password flow
                  },
                  child: Text(
                    '¿Olvidaste tu contraseña?',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              PrimaryButton(
                text: 'Iniciar sesión',
                onPressed: _isProcessing ? null : _handleLogin,
                isLoading: _isProcessing,
              ),
              
              const AuthDivider(text: 'o'),
              
              GoogleSignInButton(
                onPressed: () {},
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '¿Todavía no tenés una cuenta? ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/register');
                    },
                    child: Text(
                      'Crear una cuenta',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
