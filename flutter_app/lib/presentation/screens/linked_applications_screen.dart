import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/security_data_service.dart';
import '../widgets/buttons.dart';

class LinkedApplicationsScreen extends StatefulWidget {
  const LinkedApplicationsScreen({super.key});

  @override
  State<LinkedApplicationsScreen> createState() => _LinkedApplicationsScreenState();
}

class _LinkedApplicationsScreenState extends State<LinkedApplicationsScreen> {
  final SecurityDataService _dataService = SecurityDataService();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final applications = _dataService.getDevices().where((d) => d.type == 'external' || d.type == 'web').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicaciones Vinculadas'),
      ),
      body: applications.isEmpty
          ? Center(
              child: Text(
                'No hay aplicaciones vinculadas.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              itemCount: applications.length,
              itemBuilder: (context, index) {
                final app = applications[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(DesignTokens.spacing16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.apps, color: theme.primaryColor),
                            const SizedBox(width: DesignTokens.spacing12),
                            Expanded(
                              child: Text(
                                app.name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColorsLight.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                app.status,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: AppColorsLight.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: DesignTokens.spacing16),
                        _buildInfoRow(context, 'ID:', app.id),
                        const SizedBox(height: DesignTokens.spacing8),
                        _buildInfoRow(context, 'Tipo:', app.type.toUpperCase()),
                        const SizedBox(height: DesignTokens.spacing8),
                        _buildInfoRow(context, 'Última conexión:', '${app.lastConnectionDate} ${app.lastConnectionTime}'),
                        const SizedBox(height: DesignTokens.spacing8),
                        _buildInfoRow(context, 'Ubicación:', app.location),
                        const SizedBox(height: DesignTokens.spacing16),
                        SizedBox(
                          width: double.infinity,
                          child: TextualButton(
                            text: 'Ver Detalles',
                            onPressed: () {
                              Navigator.pushNamed(context, '/device_details', arguments: app);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/add_application');
        },
        backgroundColor: theme.primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
