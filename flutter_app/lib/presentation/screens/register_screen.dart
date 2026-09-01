import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';
import '../widgets/auth_components.dart';

/// Screen 06 - Register Screen
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _acceptedTerms = false;
  String _password = "";
  bool _isProcessing = false;

  void _onPasswordChanged(String value) {
    setState(() {
      _password = value;
    });
  }

  bool _isFormValid() {
    if (_nameController.text.trim().isEmpty) return false;
    if (_lastNameController.text.trim().isEmpty) return false;
    if (_emailController.text.trim().isEmpty) return false;
    // Simple email validation
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(_emailController.text.trim())) return false;
    if (_password.length < 8) return false;
    if (!_password.contains(RegExp(r'[A-Z]'))) return false;
    if (!_password.contains(RegExp(r'[a-z]'))) return false;
    if (!_password.contains(RegExp(r'[0-9]'))) return false;
    if (!_password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) return false;
    if (_password != _confirmPasswordController.text) return false;
    if (!_acceptedTerms) return false;
    
    return true;
  }

  void _handleRegister() async {
    setState(() {
      _isProcessing = true;
    });
    
    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
      // Navigate to registration success screen
      Navigator.pushReplacementNamed(context, '/registration_success');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
                'Creá tu cuenta',
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Comenzá a utilizar AUTHENTICATOR de forma segura.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              Row(
                children: [
                  Expanded(
                    child: StandardTextField(
                      label: 'Nombre',
                      hint: 'Ej: Juan',
                      controller: _nameController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: StandardTextField(
                      label: 'Apellido',
                      hint: 'Ej: Pérez',
                      controller: _lastNameController,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              StandardTextField(
                label: 'Correo electrónico',
                hint: 'nombre@ejemplo.com',
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                onChanged: (_) => setState(() {}),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              PasswordTextField(
                label: 'Contraseña',
                hint: 'Creá una contraseña',
                controller: _passwordController,
                onChanged: _onPasswordChanged,
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              PasswordStrengthIndicator(password: _password),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              PasswordTextField(
                label: 'Confirmar contraseña',
                hint: 'Repetí tu contraseña',
                controller: _confirmPasswordController,
                onChanged: (_) => setState(() {}),
                errorText: _confirmPasswordController.text.isNotEmpty && _password != _confirmPasswordController.text
                    ? 'Las contraseñas no coinciden'
                    : null,
              ),
              
              const SizedBox(height: DesignTokens.spacing40),
              
              LegalConsentCheckbox(
                value: _acceptedTerms,
                onChanged: (val) {
                  setState(() {
                    _acceptedTerms = val ?? false;
                  });
                },
                onTermsTap: () {
                  Navigator.pushNamed(context, '/terms');
                },
                onPrivacyTap: () {
                  Navigator.pushNamed(context, '/privacy');
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              PrimaryButton(
                text: 'Crear cuenta',
                onPressed: _isFormValid() && !_isProcessing ? _handleRegister : null,
                isLoading: _isProcessing,
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
            ],
          ),
        ),
      ),
    );
  }
}
