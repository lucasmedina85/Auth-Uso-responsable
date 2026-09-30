import '../../services/session_service.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';

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
    
    bool success = false;
    try {
      success = await SessionService.login(
        _emailController.text,
        _passwordController.text,
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        String retryAfter = e.response?.headers.value('Retry-After') ?? '60';
        int seconds = int.tryParse(retryAfter) ?? 60;
        if (mounted) {
          setState(() { _isProcessing = false; });
          _startLockoutTimer(seconds);
          return;
        }
      }
    } catch (e) {
      // Ignored
    }

    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      
      if (success) {
        String? status = await SessionService.fetchUserStatus();
        if (status == "REGISTERED") {
            Navigator.pushReplacementNamed(context, '/permissions');
        } else if (status == "LOCALLY_VERIFIED" || status == "REMOTELY_VERIFIED" || status == "PENDING_VERIFICATION") {
            Navigator.pushReplacementNamed(context, '/dashboard');
        } else {
            Navigator.pushReplacementNamed(context, '/dashboard');
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Credenciales inválidas.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  void _startLockoutTimer(int seconds) {
    setState(() {
      _lockoutSeconds = seconds;
    });
    _lockoutTimer?.cancel();
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_lockoutSeconds > 0) {
          _lockoutSeconds--;
        } else {
          timer.cancel();
        }
      });
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Demasiados intentos. Cuenta bloqueada temporalmente.'),
        backgroundColor: Colors.red,
      ),
    );
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
                text: _lockoutSeconds > 0 ? 'Reintente en $_lockoutSeconds s' : 'Iniciar sesión',
                onPressed: _isProcessing || _lockoutSeconds > 0 ? null : _handleLogin,
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
