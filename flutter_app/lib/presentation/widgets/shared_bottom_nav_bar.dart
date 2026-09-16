import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../logic/secure_storage_service.dart';
import '../../main.dart';

class SharedBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final String displayName;

  const SharedBottomNavBar({
    super.key,
    required this.currentIndex,
    this.displayName = 'Usuario',
  });

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: (index) {
        if (index == currentIndex) return;
        
        if (index == 0) {
          Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false, arguments: displayName);
        } else if (index == 1) {
          Navigator.pushNamedAndRemoveUntil(context, '/device_activity', (route) => route.settings.name == '/dashboard', arguments: {'email': displayName});
        } else if (index == 2) {
          Navigator.pushNamedAndRemoveUntil(context, '/change_password', (route) => route.settings.name == '/dashboard');
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
                const SizedBox(height: DesignTokens.spacing16),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Cómo funciona'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to how it works
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.swap_horiz),
                  title: const Text('Transferir cuentas'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushNamed(context, '/transfer_accounts');
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('Configuración'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to configuration
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Ayuda y comentarios'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to help
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Ver en modo oscuro'),
                  trailing: Switch(
                    value: theme.brightness == Brightness.dark,
                    onChanged: (val) {
                      themeNotifier.value = val ? ThemeMode.dark : ThemeMode.light;
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
                  onTap: () async {
                    Navigator.pop(context); // Cerrar bottom sheet
                    final secureStorage = SecureStorageService();
                    await secureStorage.logout();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                    }
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
