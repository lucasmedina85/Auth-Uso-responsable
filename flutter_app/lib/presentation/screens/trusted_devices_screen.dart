import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/security_data_service.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import '../widgets/buttons.dart';

class TrustedDevicesScreen extends StatefulWidget {
  const TrustedDevicesScreen({super.key});

  @override
  State<TrustedDevicesScreen> createState() => _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends State<TrustedDevicesScreen> {
  final SecurityDataService _dataService = SecurityDataService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final devices = _dataService.getDevices();

    // Split devices into physical devices and applications
    final physicalDevices = devices.where((d) => d.type != 'external').toList();
    final applications = devices.where((d) => d.type == 'external').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos Confiables'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing20,
            vertical: DesignTokens.spacing20,
          ),
          children: [
            Text(
              'Gestiona los dispositivos y aplicaciones autorizados para acceder a tu cuenta.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            
            const SizedBox(height: DesignTokens.spacing32),
            
            // Physical Devices Section
            Text(
              'Tus Dispositivos',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            ...physicalDevices.map((device) => _buildDeviceCard(context, device)),
            
            const SizedBox(height: DesignTokens.spacing32),
            
            // Applications Section
            Text(
              'Aplicativos Vinculados',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: DesignTokens.spacing16),
            ...applications.map((app) => _buildAppCard(context, app)),
          ],
        ),
      ),
      bottomNavigationBar: const SharedBottomNavBar(
        currentIndex: 0,
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, TrustedDevice device) {
    final theme = Theme.of(context);
    
    IconData icon = Icons.smartphone;
    if (device.type == 'web') icon = Icons.laptop;

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: theme.primaryColor),
                ),
                const SizedBox(width: DesignTokens.spacing16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        device.name,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        device.os,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing24),
            
            _buildDetailRow(theme, 'Aplicación:', device.associatedApp),
            _buildDetailRow(theme, 'Última conexión:', '${device.lastConnectionDate} — ${device.lastConnectionTime}'),
            _buildDetailRow(theme, 'Ubicación:', device.location),
            
            const SizedBox(height: DesignTokens.spacing8),
            
            _buildStatusBadge(theme, device.status),
            
            const SizedBox(height: DesignTokens.spacing24),
            
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                text: 'Actividad',
                onPressed: () {
                  Navigator.pushNamed(
                    context, 
                    '/device_activity',
                    arguments: device,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppCard(BuildContext context, TrustedDevice app) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(DesignTokens.spacing20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.secondary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.cloud_done_outlined, color: theme.colorScheme.secondary),
                ),
                const SizedBox(width: DesignTokens.spacing16),
                Expanded(
                  child: Text(
                    app.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing24),
            
            _buildDetailRow(theme, 'Estado:', app.status, isStatus: true),
            _buildDetailRow(theme, 'Última conexión:', '${app.lastConnectionDate} — ${app.lastConnectionTime}'),
            
            const SizedBox(height: DesignTokens.spacing24),
            
            SizedBox(
              width: double.infinity,
              child: SecondaryButton(
                text: 'Actividad',
                onPressed: () {
                  Navigator.pushNamed(
                    context, 
                    '/device_activity',
                    arguments: app,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value, {bool isStatus = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: DesignTokens.spacing8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: isStatus ? FontWeight.bold : FontWeight.normal,
                color: isStatus ? AppColorsLight.success : theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColorsLight.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 14, color: AppColorsLight.success),
          const SizedBox(width: 8),
          Text(
            status,
            style: theme.textTheme.labelSmall?.copyWith(
              color: AppColorsLight.success,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
