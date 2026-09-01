import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';
import '../widgets/totp_components.dart'; // Ensure it has QrCodeCard if we created it there, else create here

class ApplicationQrScreen extends StatelessWidget {
  const ApplicationQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final appName = args?['appName'] ?? 'Aplicación';
    final deviceName = args?['deviceName'] ?? 'Dispositivo';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vincular aplicación'),
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
              Text(
                'Escaneá este código QR desde la aplicación que querés autorizar.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing40),
              
              // Mock QR Code Box
              Center(
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    color: Colors.white,
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
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 200, color: Colors.grey.shade800),
                      // Fake corner squares for QR look
                      Positioned(top: 25, left: 25, child: Icon(Icons.crop_square, size: 40, color: theme.primaryColor)),
                      Positioned(top: 25, right: 25, child: Icon(Icons.crop_square, size: 40, color: theme.primaryColor)),
                      Positioned(bottom: 25, left: 25, child: Icon(Icons.crop_square, size: 40, color: theme.primaryColor)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing40),
              
              // App Details Info
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Nombre', appName),
                    const Divider(height: 24),
                    _buildInfoRow(context, 'Dispositivo', deviceName),
                  ],
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              TextualButton(
                text: 'Copiar clave de configuración',
                onPressed: () {
                  // Simulate biometric request to view secret
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Se requerirá autenticación biométrica para ver la clave.')),
                  );
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              PrimaryButton(
                text: 'He escaneado el código',
                onPressed: () {
                  Navigator.pushNamed(
                    context, 
                    '/application_linked',
                    arguments: {
                      'appName': appName,
                      'deviceName': deviceName,
                    }
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value) {
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
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
