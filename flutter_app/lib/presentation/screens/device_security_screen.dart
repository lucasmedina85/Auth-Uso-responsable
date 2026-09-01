import 'package:flutter/material.dart';
import 'dart:async';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/status_badges.dart';

/// Screen 02 - Device Security Check
class DeviceSecurityScreen extends StatefulWidget {
  const DeviceSecurityScreen({super.key});

  @override
  State<DeviceSecurityScreen> createState() => _DeviceSecurityScreenState();
}

class _DeviceSecurityScreenState extends State<DeviceSecurityScreen> {
  bool _isChecking = true;
  bool _isSecure = false;

  @override
  void initState() {
    super.initState();
    _performSecurityChecks();
  }

  Future<void> _performSecurityChecks() async {
    // Simulate checking device security
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() {
        _isChecking = false;
        _isSecure = true; // Assume secure for MVP flow
      });
      
      // Auto advance to welcome if secure
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted && _isSecure) {
          Navigator.pushReplacementNamed(context, '/welcome');
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Comprobación de Seguridad'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Verificando tu dispositivo',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Estamos comprobando si tu dispositivo cumple con nuestros estándares de seguridad antes de continuar.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing48),
              
              _buildCheckItem(
                'Verificación de Bloqueo de Pantalla',
                _isChecking ? BadgeStatus.pending : (_isSecure ? BadgeStatus.verified : BadgeStatus.error),
                theme,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              _buildCheckItem(
                'Integridad del Dispositivo',
                _isChecking ? BadgeStatus.pending : (_isSecure ? BadgeStatus.verified : BadgeStatus.error),
                theme,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              _buildCheckItem(
                'Análisis Root/Jailbreak',
                _isChecking ? BadgeStatus.pending : (_isSecure ? BadgeStatus.verified : BadgeStatus.error),
                theme,
              ),
              
              const Spacer(),
              
              if (!_isChecking && !_isSecure)
                DestructiveButton(
                  text: 'Contactar a Soporte',
                  onPressed: () {},
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCheckItem(String title, BadgeStatus status, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(DesignTokens.spacing16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          if (status == BadgeStatus.pending)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            StatusBadge(
              text: status == BadgeStatus.verified ? 'Seguro' : 'Falló',
              status: status,
              outlined: true,
            ),
        ],
      ),
    );
  }
}
