import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/totp_components.dart';

class AuthenticatorDashboardScreen extends StatefulWidget {
  const AuthenticatorDashboardScreen({super.key});

  @override
  State<AuthenticatorDashboardScreen> createState() => _AuthenticatorDashboardScreenState();
}

class _AuthenticatorDashboardScreenState extends State<AuthenticatorDashboardScreen> {
  // Mock list of applications
  List<Map<String, String>> _applications = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // If navigated from application_linked with arguments, add to the list
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null && _applications.isEmpty) {
      _applications.add({
        'appName': args['appName'] ?? 'Aplicación',
        'deviceName': args['deviceName'] ?? 'Dispositivo',
        'appId': 'app_${DateTime.now().millisecondsSinceEpoch}',
      });
    } else if (_applications.isEmpty) {
      // Mock some data if nothing was passed
      _applications.add({
        'appName': 'Plataforma de Juegos',
        'deviceName': 'Mi teléfono personal',
        'appId': 'app_123',
      });
    }
  }

  void _showMenu(BuildContext context, Map<String, String> app) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLarge)),
      ),
      builder: (context) => _buildBottomSheetMenu(context, app),
    );
  }

  Widget _buildBottomSheetMenu(BuildContext context, Map<String, String> app) {
    final theme = Theme.of(context);
    
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: DesignTokens.spacing8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: DesignTokens.spacing16),
          Text(
            app['appName']!,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          const Divider(),
          _buildMenuTile(context, Icons.info_outline, 'Ver detalles', () {
            Navigator.pop(context);
            Navigator.pushNamed(context, '/device_details', arguments: app);
          }),
          _buildMenuTile(context, Icons.edit_outlined, 'Cambiar nombre', () {
            Navigator.pop(context);
          }),
          _buildMenuTile(context, Icons.smartphone_outlined, 'Ver dispositivo', () {
            Navigator.pop(context);
          }),
          _buildMenuTile(context, Icons.pause_circle_outline, 'Pausar temporalmente', () {
            Navigator.pop(context);
          }),
          const Divider(),
          _buildMenuTile(
            context, 
            Icons.delete_outline, 
            'Eliminar aplicación', 
            () {
              Navigator.pop(context);
              _showDeleteConfirmation(app);
            },
            isDestructive: true,
          ),
          const SizedBox(height: DesignTokens.spacing16),
        ],
      ),
    );
  }

  ListTile _buildMenuTile(BuildContext context, IconData icon, String title, VoidCallback onTap, {bool isDestructive = false}) {
    final theme = Theme.of(context);
    final color = isDestructive ? theme.colorScheme.error : theme.colorScheme.onSurface;
    
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          color: color,
          fontWeight: isDestructive ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      onTap: onTap,
    );
  }

  void _showDeleteConfirmation(Map<String, String> app) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          '¿Eliminar aplicación?',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: const Text(
          'Esta acción impedirá generar nuevos códigos para esta aplicación desde este dispositivo.',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancelar',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            onPressed: () {
              setState(() {
                _applications.remove(app);
              });
              Navigator.pop(context);
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final isClassHours = now.hour >= 7 && now.hour < 17;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Authenticator'),
      ),
      body: SafeArea(
        child: isClassHours
            ? _buildTimeBlockedState(theme)
            : _applications.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: DesignTokens.spacing24,
                      vertical: DesignTokens.spacing24,
                    ),
                    itemCount: _applications.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: DesignTokens.spacing24),
                          child: Text(
                            'Tus códigos de seguridad',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        );
                      }
                      
                      final app = _applications[index - 1];
                      return ApplicationCard(
                        appName: app['appName']!,
                        deviceName: app['deviceName']!,
                        applicationId: app['appId']!,
                        onCopy: () {},
                        onMenuTap: () => _showMenu(context, app),
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildTimeBlockedState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.access_time_filled,
            size: 80,
            color: theme.colorScheme.error,
          ),
          const SizedBox(height: DesignTokens.spacing24),
          Text(
            'Generación Bloqueada',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            'Por políticas de seguridad (CU-0022), no se permite generar códigos de autenticación durante el horario de clases (07:00 a 17:00 hs).\n\nPodrás generar códigos fuera de este horario.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(DesignTokens.spacing24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.security_outlined,
            size: 80,
            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: DesignTokens.spacing24),
          Text(
            'Todavía no tenés aplicaciones vinculadas.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing8),
          Text(
            'Para vincular una aplicación, debes realizar el proceso de verificación de identidad.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: DesignTokens.spacing48),
          PrimaryButton(
            text: 'Verificar Identidad',
            onPressed: () {
              Navigator.pushNamed(context, '/dni_capture');
            },
          ),
        ],
      ),
    );
  }
}
