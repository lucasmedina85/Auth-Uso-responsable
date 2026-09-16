import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../logic/security_data_service.dart';
import '../widgets/totp_components.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

class AddApplicationScreen extends StatefulWidget {
  const AddApplicationScreen({super.key});

  @override
  State<AddApplicationScreen> createState() => _AddApplicationScreenState();
}

class _AddApplicationScreenState extends State<AddApplicationScreen> {
  final TextEditingController _appNameController = TextEditingController();
  final TextEditingController _deviceNameController = TextEditingController();
  String _selectedType = '';
  
  // Generated ID
  final String _techId = 'DISP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7, 13)}';

  final List<Map<String, dynamic>> _appTypes = [
    {'id': 'web', 'label': 'Aplicación web', 'icon': Icons.language},
    {'id': 'mobile', 'label': 'Aplicación móvil', 'icon': Icons.smartphone},
    {'id': 'external', 'label': 'Plataforma externa', 'icon': Icons.cloud_outlined},
    {'id': 'other', 'label': 'Otro', 'icon': Icons.apps},
  ];

  @override
  void dispose() {
    _appNameController.dispose();
    _deviceNameController.dispose();
    super.dispose();
  }

  bool _isFormValid() {
    return _appNameController.text.trim().isNotEmpty && 
           _deviceNameController.text.trim().isNotEmpty && 
           _selectedType.isNotEmpty;
  }

  void _submitApplication() {
    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    final newDevice = TrustedDevice(
      id: _techId,
      name: _appNameController.text.trim(),
      type: _selectedType,
      os: _deviceNameController.text.trim(),
      associatedApp: _appNameController.text.trim(),
      status: 'Autorizada',
      lastConnectionDate: dateStr,
      lastConnectionTime: timeStr,
      location: 'Buenos Aires, Argentina',
    );

    // Save to central storage/table
    SecurityDataService().addDevice(newDevice);

    Navigator.pushNamed(
      context, 
      '/application_qr',
      arguments: {
        'device': newDevice,
        'appName': _appNameController.text.trim(),
        'deviceName': _deviceNameController.text.trim(),
        'techId': _techId,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar aplicación'),
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
                'Registrá una aplicación para generar códigos de acceso seguros.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              ApplicationCard(
                appName: 'Mi Autenticador',
                deviceName: 'Este dispositivo',
                applicationId: 'auth_key',
                onCopy: () {},
                onMenuTap: () {},
              ),
              const SizedBox(height: DesignTokens.spacing32),
              const SizedBox(height: DesignTokens.spacing32),
              
              StandardTextField(
                label: 'Nombre de la aplicación',
                hint: 'Ej.: Plataforma de Juegos',
                controller: _appNameController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: DesignTokens.spacing24),
              
              StandardTextField(
                label: 'Nombre del dispositivo',
                hint: 'Ej.: Mi teléfono personal',
                controller: _deviceNameController,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: DesignTokens.spacing24),

              Text(
                'Identificador (Opcional)',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(DesignTokens.spacing16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: Text(
                  _techId,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              Text(
                'Tipo de aplicación',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: DesignTokens.spacing12,
                  mainAxisSpacing: DesignTokens.spacing12,
                  childAspectRatio: 1.5,
                ),
                itemCount: _appTypes.length,
                itemBuilder: (context, index) {
                  final type = _appTypes[index];
                  final isSelected = _selectedType == type['id'];
                  
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedType = type['id'];
                      });
                    },
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? theme.primaryColor.withOpacity(0.1) : theme.cardTheme.color,
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                        border: Border.all(
                          color: isSelected ? theme.primaryColor : theme.colorScheme.outlineVariant,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            type['icon'],
                            color: isSelected ? theme.primaryColor : theme.colorScheme.onSurfaceVariant,
                            size: 28,
                          ),
                          const SizedBox(height: DesignTokens.spacing8),
                          Text(
                            type['label'],
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isSelected ? theme.primaryColor : theme.colorScheme.onSurface,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing48),
              
              PrimaryButton(
                text: 'Continuar',
                onPressed: _isFormValid() ? _submitApplication : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
