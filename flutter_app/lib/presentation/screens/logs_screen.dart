import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_theme.dart';

/// Item model for simulated audit log records.
class AuditLogItem {
  final String id;
  final String useCase;
  final String title;
  final String timestamp;
  final String statusText;
  final Color statusColor;
  final IconData icon;

  AuditLogItem({
    required this.id,
    required this.useCase,
    required this.title,
    required this.timestamp,
    required this.statusText,
    required this.statusColor,
    required this.icon,
  });
}

/// Pantalla 5 (Log estado de situación): Interfaz basada en ListView que muestra el historial
/// de validaciones simulando un registro actual. Debe contener un AppBar nativo con botón "Volver atrás".
class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  List<AuditLogItem> _getSimulatedLogs() {
    return [
      AuditLogItem(
        id: 'LOG-0015',
        useCase: 'CU-0036',
        title: 'Permisos Dinámicos SO',
        timestamp: 'Hoy, 12:44:12',
        statusText: 'PERMITIDO',
        statusColor: AppColors.validationGreen,
        icon: Icons.security_rounded,
      ),
      AuditLogItem(
        id: 'LOG-0014',
        useCase: 'CU-0021',
        title: 'Estado de Bloqueo Pantalla',
        timestamp: 'Hoy, 12:43:50',
        statusText: 'VERIFICADO',
        statusColor: AppColors.validationGreen,
        icon: Icons.lock_outline_rounded,
      ),
      AuditLogItem(
        id: 'LOG-0013',
        useCase: 'CU-0007',
        title: 'Validación Regla Mayoría de Edad (18+)',
        timestamp: 'Hoy, 12:41:05',
        statusText: 'APROBADO (>18)',
        statusColor: AppColors.validationGreen,
        icon: Icons.cake_outlined,
      ),
      AuditLogItem(
        id: 'LOG-0012',
        useCase: 'CU-0005',
        title: 'Vigencia de Documento DNI',
        timestamp: 'Hoy, 12:40:22',
        statusText: 'VIGENTE',
        statusColor: AppColors.validationGreen,
        icon: Icons.assignment_turned_in_outlined,
      ),
      AuditLogItem(
        id: 'LOG-0011',
        useCase: 'CU-0013',
        title: 'Prueba de Vida Activa (Liveness)',
        timestamp: 'Hoy, 12:38:10',
        statusText: 'SUPERADO (99.4%)',
        statusColor: AppColors.validationGreen,
        icon: Icons.face_retouching_natural_rounded,
      ),
      AuditLogItem(
        id: 'LOG-0010',
        useCase: 'CU-0041',
        title: 'Detección Error Hardware Cámara',
        timestamp: 'Ayer, 18:22:45',
        statusText: 'ADVERTENCIA',
        statusColor: AppColors.warningYellow,
        icon: Icons.camera_enhance_outlined,
      ),
      AuditLogItem(
        id: 'LOG-0009',
        useCase: 'CU-0042',
        title: 'Fallback Formulario OCR Manual',
        timestamp: 'Ayer, 18:20:11',
        statusText: 'COMPLETADO',
        statusColor: AppColors.validationGreen,
        icon: Icons.keyboard_alt_outlined,
      ),
      AuditLogItem(
        id: 'LOG-0008',
        useCase: 'CU-0023',
        title: 'Evaluación Score de Riesgo Dispositivo',
        timestamp: 'Hace 2 días',
        statusText: 'RIESGO BAJO (0.02)',
        statusColor: AppColors.validationGreen,
        icon: Icons.speed_rounded,
      ),
      AuditLogItem(
        id: 'LOG-0007',
        useCase: 'CU-0046',
        title: 'Verificación Versión de Cliente',
        timestamp: 'Hace 2 días',
        statusText: 'VERSION 1.0.0 (OK)',
        statusColor: AppColors.validationGreen,
        icon: Icons.system_update_rounded,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final logs = _getSimulatedLogs();

    return Scaffold(
      backgroundColor: AppColors.neutralLightGray,
      appBar: AppBar(
        title: Text(
          'Log Estado de Situación',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Volver atrás',
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Summary Banner
            Container(
              padding: const EdgeInsets.all(16),
              color: AppColors.deepGraphite,
              child: Row(
                children: [
                  const Icon(Icons.receipt_long_rounded, color: AppColors.industrialBlue, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AUDITORÍA Y HISTORIAL LOCAL',
                          style: GoogleFonts.montserrat(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Registro en tiempo real de operaciones de validación KYC.',
                          style: GoogleFonts.montserrat(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ListView of Audit Log Cards
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  final item = logs[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: item.statusColor.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        ),
                        child: Icon(item.icon, color: item.statusColor, size: 24),
                      ),
                      title: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.deepGraphite,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.useCase,
                              style: GoogleFonts.montserrat(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              item.title,
                              style: GoogleFonts.montserrat(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppColors.deepGraphite,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          'ID: ${item.id} | ${item.timestamp}',
                          style: GoogleFonts.montserrat(
                            fontSize: 11,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: item.statusColor,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        ),
                        child: Text(
                          item.statusText,
                          style: GoogleFonts.montserrat(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
