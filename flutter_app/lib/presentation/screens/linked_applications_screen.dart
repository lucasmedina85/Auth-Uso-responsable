import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/database_log_service.dart';

class LinkedApplicationsScreen extends StatefulWidget {
  const LinkedApplicationsScreen({super.key});

  @override
  State<LinkedApplicationsScreen> createState() => _LinkedApplicationsScreenState();
}

class _LinkedApplicationsScreenState extends State<LinkedApplicationsScreen> {
  List<Map<String, dynamic>> _applications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    final apps = await LinkedAppsService().getLinkedApps();
    setState(() {
      _applications = apps;
      _isLoading = false;
    });
  }

  Future<void> _unlinkApp(String id) async {
    await LinkedAppsService().unlinkApp(id);
    await DatabaseLogService().logEvent('APP_UNLINKED', 'App desvinculada: $id', 'SUCCESS');
    _loadApps();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicaciones Vinculadas'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _applications.isEmpty
          ? Center(
              child: Text(
                'No hay aplicaciones vinculadas.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(DesignTokens.spacing16),
              itemCount: _applications.length,
              separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spacing12),
              itemBuilder: (context, index) {
                final app = _applications[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(DesignTokens.spacing16),
                    leading: CircleAvatar(
                      backgroundColor: theme.colorScheme.primaryContainer,
                      child: Icon(Icons.apps, color: theme.colorScheme.onPrimaryContainer),
                    ),
                    title: Text(
                      app['name'],
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: DesignTokens.spacing8),
                      child: Text('Vinculada el: ${app['addedAt']}'),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _unlinkApp(app['id']),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
