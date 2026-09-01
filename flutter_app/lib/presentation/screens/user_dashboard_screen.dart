import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/security_score.dart';


/// Screen 39 - User Dashboard
class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments;
    final String displayName = (args != null && args is String) ? args : 'Usuario';

    return Scaffold(
      appBar: AppBar(
        title: const Text('AUTHENTICATOR'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () {},
          ),
          const SizedBox(width: DesignTokens.spacing8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Header
              Text(
                'Hola, $displayName',
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Tu identidad está verificada y segura.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Security Score
              const SecurityScoreCard(
                score: 98,
                level: SecurityRiskLevel.secure,
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Status Card
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing20),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
                  border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(DesignTokens.spacing12),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.verified_user, color: theme.primaryColor),
                    ),
                    const SizedBox(width: DesignTokens.spacing16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alta Confianza',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing4),
                          Text(
                            'Última vez: Hoy, 10:45 AM',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Quick Actions
              Text(
                'Acciones Rápidas',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: DesignTokens.spacing16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(context, Icons.fingerprint, 'Verificar\nIdentidad', () {
                      Navigator.pushNamed(context, '/dni_capture');
                    }),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: _buildActionCard(context, Icons.history, 'Actividad', () {
                      Navigator.pushNamed(context, '/device_activity', arguments: {'email': displayName});
                    }),
                  ),
                ],
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(context, Icons.devices, 'Dispositivos\nConfiables', () {
                      Navigator.pushNamed(context, '/trusted_devices');
                    }),
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: _buildActionCard(context, Icons.security, 'Seguridad', () {
                      Navigator.pushNamed(context, '/change_password');
                    }),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          if (index == 0) return;
          if (index == 1) {
            Navigator.pushNamed(context, '/device_activity', arguments: {'email': displayName});
          } else if (index == 2) {
            Navigator.pushNamed(context, '/change_password');
          } else if (index == 3) {
            _showSettingsBottomSheet(context);
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Actividad',
          ),
          NavigationDestination(
            icon: Icon(Icons.security_outlined),
            selectedIcon: Icon(Icons.security),
            label: 'Seguridad',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
      child: Container(
        padding: const EdgeInsets.all(DesignTokens.spacing16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.primaryColor, size: 28),
            const SizedBox(height: DesignTokens.spacing16),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(DesignTokens.radiusLarge)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(DesignTokens.spacing24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ajustes',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: DesignTokens.spacing24),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Modo Oscuro'),
                  trailing: Switch(
                    value: theme.brightness == Brightness.dark,
                    onChanged: (val) {
                      // Note: In a real app this would call a ThemeProvider.
                      // For this prototype, we'll just show a snackbar.
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cambio de tema no implementado en este prototipo sin estado global.')),
                      );
                    },
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: Icon(Icons.logout, color: theme.colorScheme.error),
                  title: Text(
                    'Cerrar sesión',
                    style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
