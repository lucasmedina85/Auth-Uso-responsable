import '../../services/session_service.dart';
import '../../core/security/screen_lock_service.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';

import '../widgets/inputs.dart';
import '../widgets/auth_components.dart';
import '../widgets/behavior_tracker.dart';
import '../widgets/demo_mode_banner.dart';
import '../../core/config/app_config.dart';

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
  String? _emailError;
  String? _passwordError;
  bool _canRememberSession = false;
  bool _rememberSession = false;

  @override
  void initState() {
    super.initState();
    ScreenLockService().isScreenLockConfigured().then((configured) {
      if (mounted) {
        setState(() {
          _canRememberSession = configured;
        });
      }
    });
  }

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
      _emailError = null;
      _passwordError = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;
    bool hasError = false;

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (email.isEmpty) {
      setState(() => _emailError = 'El correo electrónico es requerido.');
      hasError = true;
    } else if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Ingresá un formato de correo electrónico válido.');
      hasError = true;
    }

    if (password.isEmpty) {
      setState(() => _passwordError = 'La contraseña es requerida.');
      hasError = true;
    }

    if (hasError) return;

    setState(() {
      _isProcessing = true;
    });
    
    bool success = false;
    try {
      success = await SessionService.login(
        email,
        password,
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
      } else if (e.response == null ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.receiveTimeout) {
        if (mounted) {
          setState(() { _isProcessing = false; });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No se pudo conectar con el servidor. Verifique su conexión de red.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
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
        await SessionService.setRememberSession(_rememberSession);
        String? status = await SessionService.fetchUserStatus();
        if (!mounted) return;
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
        content: Text('Demasiados intentos, probá más tarde.'),
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

    return BehaviorTracker(
      screenName: 'LoginScreen',
      child: Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoModeBanner(),
            Expanded(
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
                    
                    if (AppConfig.isLocal) ...[
                      const SizedBox(height: DesignTokens.spacing16),
                      InkWell(
                        onTap: () {
                          setState(() {
                            _emailController.text = 'demo@sip.local';
                            _passwordController.text = 'Demo12345!';
                            _emailError = null;
                            _passwordError = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: theme.colorScheme.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.key_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Cargar credenciales demo: demo@sip.local / Demo12345!',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: DesignTokens.spacing24),
                    ] else ...[
                      const SizedBox(height: DesignTokens.spacing48),
                    ],
                    
                    Semantics(
                      label: 'Campo de texto para correo electrónico',
                      textField: true,
                      child: StandardTextField(
                        label: 'Correo electrónico',
                        hint: 'nombre@ejemplo.com',
                        controller: _emailController,
                        errorText: _emailError,
                        enabled: !_isProcessing,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: (_) {
                          if (_emailError != null) setState(() => _emailError = null);
                        },
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing24),
                    Semantics(
                      label: 'Campo de texto para contraseña',
                      textField: true,
                      child: PasswordTextField(
                        label: 'Contraseña',
                        hint: 'Ingresá tu contraseña',
                        controller: _passwordController,
                        errorText: _passwordError,
                        enabled: !_isProcessing,
                        onChanged: (_) {
                          if (_passwordError != null) setState(() => _passwordError = null);
                        },
                      ),
                    ),
                    const SizedBox(height: DesignTokens.spacing16),

              Semantics(
                label: 'Casilla para mantener la sesión iniciada',
                child: CheckboxListTile(
                  value: _rememberSession,
                  onChanged: _canRememberSession && !_isProcessing
                      ? (val) {
                          setState(() {
                            _rememberSession = val ?? false;
                          });
                        }
                      : null,
                  title: Text(
                    'Mantener sesión iniciada',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: _canRememberSession ? theme.colorScheme.onSurface : theme.disabledColor,
                    ),
                  ),
                  subtitle: !_canRememberSession
                      ? Text(
                          'Para mantener la sesión iniciada se requiere que el dispositivo tenga configurado bloqueo de pantalla o biometría.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        )
                      : null,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
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
              
              Semantics(
                label: 'Botón para iniciar sesión',
                button: true,
                enabled: !_isProcessing && _lockoutSeconds == 0,
                child: PrimaryButton(
                  text: _lockoutSeconds > 0 ? 'Reintente en $_lockoutSeconds s' : 'Iniciar sesión',
                  onPressed: _isProcessing || _lockoutSeconds > 0 ? null : _handleLogin,
                  isLoading: _isProcessing,
                ),
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
      ],
    ),
  ),
),
);
  }
}
