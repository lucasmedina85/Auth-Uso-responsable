import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _hasLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasNumber = false;
  bool _hasSpecial = false;

  @override
  void initState() {
    super.initState();
    _newPasswordController.addListener(_validatePassword);
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _validatePassword() {
    final pass = _newPasswordController.text;
    setState(() {
      _hasLength = pass.length >= 8;
      _hasUppercase = pass.contains(RegExp(r'[A-Z]'));
      _hasLowercase = pass.contains(RegExp(r'[a-z]'));
      _hasNumber = pass.contains(RegExp(r'[0-9]'));
      _hasSpecial = pass.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));
    });
  }

  bool _isFormValid() {
    return _hasLength &&
           _hasUppercase &&
           _hasLowercase &&
           _hasNumber &&
           _hasSpecial &&
           _currentPasswordController.text.isNotEmpty &&
           _newPasswordController.text == _confirmPasswordController.text;
  }

  String _getStrengthText() {
    int score = [_hasLength, _hasUppercase, _hasLowercase, _hasNumber, _hasSpecial]
        .where((e) => e)
        .length;
    
    if (score <= 1) return 'Débil';
    if (score <= 3) return 'Media';
    if (score == 4) return 'Fuerte';
    return 'Muy fuerte';
  }

  Color _getStrengthColor(ThemeData theme) {
    int score = [_hasLength, _hasUppercase, _hasLowercase, _hasNumber, _hasSpecial]
        .where((e) => e)
        .length;
    
    if (score <= 1) return theme.colorScheme.error;
    if (score <= 3) return AppColorsLight.warning;
    return AppColorsLight.success;
  }

  void _handleSubmit() {
    if (_currentPasswordController.text != 'admin123') { // Mock check
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('La contraseña actual no es correcta.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      return;
    }

    // Show Confirmation Dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Cambiar contraseña?'),
        content: const Text('Tu contraseña será actualizada y las sesiones activas podrían requerir una nueva autenticación.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Go back to previous screen
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Contraseña actualizada correctamente.'),
                  backgroundColor: AppColorsLight.success,
                ),
              );
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strengthColor = _getStrengthColor(theme);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cambiar contraseña'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing24,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Actualiza la contraseña para mantener segura tu cuenta.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),
              
              PasswordTextField(
                label: 'Contraseña actual',
                hint: 'Ingresa tu contraseña actual',
                controller: _currentPasswordController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              
              PasswordTextField(
                label: 'Nueva contraseña',
                hint: 'Crea una contraseña segura',
                controller: _newPasswordController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              
              // Strength Indicator
              if (_newPasswordController.text.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                    border: Border.all(color: strengthColor.withOpacity(0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Seguridad de la contraseña',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            _getStrengthText(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: strengthColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: DesignTokens.spacing12),
                      _buildChecklistItem(theme, 'Al menos 8 caracteres', _hasLength),
                      _buildChecklistItem(theme, 'Una letra mayúscula', _hasUppercase),
                      _buildChecklistItem(theme, 'Una letra minúscula', _hasLowercase),
                      _buildChecklistItem(theme, 'Un número', _hasNumber),
                      _buildChecklistItem(theme, 'Un carácter especial', _hasSpecial),
                    ],
                  ),
                ),
                
              const SizedBox(height: DesignTokens.spacing24),
              
              PasswordTextField(
                label: 'Confirmar nueva contraseña',
                hint: 'Repite tu nueva contraseña',
                controller: _confirmPasswordController,
                onChanged: (_) => setState(() {}),
              ),
              
              if (_newPasswordController.text.isNotEmpty &&
                  _confirmPasswordController.text.isNotEmpty &&
                  _newPasswordController.text != _confirmPasswordController.text)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    'Las contraseñas no coinciden.',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),

              const SizedBox(height: DesignTokens.spacing48),
              
              PrimaryButton(
                text: 'Cambiar contraseña',
                onPressed: _isFormValid() ? _handleSubmit : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChecklistItem(ThemeData theme, String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: isValid ? AppColorsLight.success : theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isValid ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
              decoration: isValid ? TextDecoration.lineThrough : null,
            ),
          ),
        ],
      ),
    );
  }
}
