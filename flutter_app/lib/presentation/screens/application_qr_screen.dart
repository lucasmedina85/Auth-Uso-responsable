import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../logic/security_data_service.dart';
import '../widgets/buttons.dart';

class ApplicationQrScreen extends StatelessWidget {
  const ApplicationQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    final appName = args?['appName'] ?? 'Aplicación';
    final deviceName = args?['deviceName'] ?? 'Dispositivo';
    final techId = args?['techId'] ?? 'DISP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}';
    
    final TrustedDevice device = args?['device'] as TrustedDevice? ?? SecurityDataService().getLatestDevice();

    final qrPayloadUrl = 'https://auth.juegoresponsable.gov.ar/login?device_id=$techId&app=${Uri.encodeComponent(appName)}';

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
              const SizedBox(height: DesignTokens.spacing24),
              
              // Mock QR Code Box with Link Payload
              Center(
                child: Container(
                  width: 240,
                  height: 240,
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
                      Icon(Icons.qr_code_2, size: 190, color: Colors.grey.shade800),
                      Positioned(top: 20, left: 20, child: Icon(Icons.crop_square, size: 36, color: theme.primaryColor)),
                      Positioned(top: 20, right: 20, child: Icon(Icons.crop_square, size: 36, color: theme.primaryColor)),
                      Positioned(bottom: 20, left: 20, child: Icon(Icons.crop_square, size: 36, color: theme.primaryColor)),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              // Link inside QR payload text display
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                ),
                child: Row(
                  children: [
                    Icon(Icons.link, size: 16, color: theme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        qrPayloadUrl,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              // App & Login Details Info
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                ),
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Aplicación', appName),
                    const Divider(height: 20),
                    _buildInfoRow(context, 'Dispositivo', deviceName),
                    const Divider(height: 20),
                    _buildInfoRow(context, 'ID Dispositivo', techId),
                    const Divider(height: 20),
                    _buildInfoRow(context, 'Estado Login', 'Esperando Autorización', isStatus: true),
                  ],
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing20),
              
              SecondaryButton(
                text: 'Ver Actividad en Dispositivo',
                onPressed: () {
                  Navigator.pushNamed(
                    context, 
                    '/device_activity',
                    arguments: device,
                  );
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing12),
              
              TextualButton(
                text: 'Copiar clave de configuración',
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Clave de acceso y enlace copiados al portapapeles.')),
                  );
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              PrimaryButton(
                text: 'He escaneado el código',
                onPressed: () {
                  Navigator.pushNamed(
                    context, 
                    '/application_linked',
                    arguments: {
                      'appName': appName,
                      'deviceName': deviceName,
                      'device': device,
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {bool isStatus = false}) {
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
            color: isStatus ? theme.primaryColor : theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
