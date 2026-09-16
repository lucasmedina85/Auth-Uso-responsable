import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';

class DeviceDetailsScreen extends StatelessWidget {
  const DeviceDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, String>?;
    final deviceName = args?['deviceName'] ?? 'Mi teléfono personal';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivo autorizado'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
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
              Center(
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing20),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.smartphone,
                    size: 64,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),
              
              // Device Details Container
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Nombre', deviceName),
                    const Divider(height: 32),
                    _buildInfoRow(context, 'Aplicaciones vinculadas', '3'),
                    const Divider(height: 32),
                    _buildInfoRow(
                      context, 
                      'Estado', 
                      'Activo', 
                      valueColor: AppColorsLight.success,
                    ),
                    const Divider(height: 32),
                    _buildInfoRow(context, 'Última actividad', 'Hoy, 15:42'),
                    const Divider(height: 32),
                    _buildInfoRow(
                      context, 
                      'Nivel de seguridad', 
                      'Alto', 
                      valueColor: AppColorsLight.success,
                      icon: Icons.shield,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              SecondaryButton(
                text: 'Administrar dispositivo',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Abriendo configuración del dispositivo...')),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? valueColor, IconData? icon}) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: valueColor ?? theme.colorScheme.onSurface),
              const SizedBox(width: DesignTokens.spacing4),
            ],
            Expanded(
              child: Text(
                value,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: valueColor ?? theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
