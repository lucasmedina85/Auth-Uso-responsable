import 'package:flutter/material.dart';
import '../../core/theme/design_tokens.dart';
import '../../logic/security_data_service.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class ValidationConfigScreen extends StatelessWidget {
  const ValidationConfigScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dataService = SecurityDataService();
    final args = ModalRoute.of(context)?.settings.arguments as Map?;
    final email = args?['email'] ?? 'Usuario Validado';
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración de Cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User info header
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person_outline, size: 40, color: theme.primaryColor),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                email,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: DesignTokens.spacing4),
              Text(
                'Identidad verificada exitosamente',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              Text(
                'Datos de Validación Biométrica',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              
              // Evidences
              if (dataService.dniFrontPath != null) ...[
                const Text('DNI Frontal'),
                const SizedBox(height: DesignTokens.spacing8),
                _buildImage(dataService.dniFrontPath!),
                const SizedBox(height: DesignTokens.spacing16),
              ],
              
              if (dataService.dniBackPath != null) ...[
                const Text('DNI Reverso (o manual)'),
                const SizedBox(height: DesignTokens.spacing8),
                _buildImage(dataService.dniBackPath!),
                const SizedBox(height: DesignTokens.spacing16),
              ],

              if (dataService.livenessVideoPath != null) ...[
                const Text('Prueba de Vida (Captura)'),
                const SizedBox(height: DesignTokens.spacing8),
                _buildImage(dataService.livenessVideoPath!),
                const SizedBox(height: DesignTokens.spacing16),
              ],
              
              const Divider(),
              const SizedBox(height: DesignTokens.spacing16),
              
              Text(
                'Vincular Nuevo Dispositivo',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Icon(Icons.qr_code_2, size: 150, color: Colors.black),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing16),
              Text(
                'Código generado: 934-102',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: DesignTokens.spacing8),
              Text(
                'Escaneá este código QR o ingresá el código numérico para sincronizar el estado de validación con una nueva terminal.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildImage(String path) {
    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        if (kIsWeb || path.startsWith('assets/')) {
           return Container(
             height: 150,
             decoration: BoxDecoration(
               color: isDark ? Colors.grey[850] : Colors.grey.withOpacity(0.1),
               borderRadius: BorderRadius.circular(8),
               border: Border.all(color: isDark ? Colors.grey[700]! : Colors.grey[300]!),
             ),
             child: Center(
               child: Text(
                 'Imagen guardada:\n$path', 
                 textAlign: TextAlign.center,
                 style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
               ),
             ),
           );
        } else {
           return ClipRRect(
             borderRadius: BorderRadius.circular(8),
             child: Image.file(File(path), height: 150, width: double.infinity, fit: BoxFit.cover),
           );
        }
      }
    );
  }
}
