import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';

class TransferAccountsScreen extends StatelessWidget {
  const TransferAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: DesignTokens.spacing24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: DesignTokens.spacing32),
                    Icon(
                      Icons.compare_arrows,
                      size: 48,
                      color: theme.primaryColor,
                    ),
                    const SizedBox(height: DesignTokens.spacing24),
                    Text(
                      'Transferir cuentas',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignTokens.spacing16),
                    Text(
                      'Puedes transferir tus cuentas a un dispositivo nuevo con Authenticator.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: DesignTokens.spacing48),
                    const Divider(),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      leading: Icon(Icons.send_to_mobile, color: theme.primaryColor, size: 32),
                      title: const Text('Exportar cuentas', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Crea un código QR para exportar tus cuentas'),
                      onTap: () {
                        // TODO: Implement export functionality
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                      leading: Icon(Icons.install_mobile, color: theme.primaryColor, size: 32),
                      title: const Text('Importar cuentas', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const Text('Escanea un código QR para agregar cuentas nuevas'),
                      onTap: () {
                        // TODO: Implement import functionality
                      },
                    ),
                    const Divider(),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(DesignTokens.spacing24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/device_activity');
                  },
                  child: Text(
                    'Actividad reciente',
                    style: TextStyle(
                      color: theme.primaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
