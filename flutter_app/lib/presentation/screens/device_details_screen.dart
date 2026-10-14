import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/device_model.dart';
import '../../services/device_management_service.dart';

class DeviceDetailsScreen extends StatefulWidget {
  const DeviceDetailsScreen({super.key});

  @override
  State<DeviceDetailsScreen> createState() => _DeviceDetailsScreenState();
}

class _DeviceDetailsScreenState extends State<DeviceDetailsScreen> {
  final DeviceManagementService _deviceService = DeviceManagementService();
  bool _isProcessing = false;

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'No disponible';
    return DateFormat('dd/MM/yyyy HH:mm').format(dt);
  }

  Future<void> _approveDevice(DeviceModel device) async {
    setState(() => _isProcessing = true);
    try {
      await _deviceService.approveDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispositivo "${device.deviceName}" aprobado exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al aprobar el dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _revokeDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar acceso'),
        content: Text('¿Deseas revocar el acceso a "${device.deviceName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Revocar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await _deviceService.revokeDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Acceso revocado a "${device.deviceName}".'),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al revocar el dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final args = ModalRoute.of(context)?.settings.arguments;

    DeviceModel? device;
    if (args is DeviceModel) {
      device = args;
    }

    final deviceName = device?.deviceName ?? 'Dispositivo';
    final isRevoked = device?.status == 'REVOKED';
    final isPending = device?.status == 'PENDING';
    final isTrusted = device?.status == 'TRUSTED';

    String statusLabel = 'Desconocido';
    Color statusColor = theme.colorScheme.onSurface;
    if (isTrusted) {
      statusLabel = 'Confiable';
      statusColor = AppColorsLight.success;
    } else if (isPending) {
      statusLabel = 'Pendiente de aprobación';
      statusColor = AppColorsLight.warning;
    } else if (isRevoked) {
      statusLabel = 'Acceso revocado';
      statusColor = AppColorsLight.error;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del dispositivo'),
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
              Center(
                child: Container(
                  padding: const EdgeInsets.all(DesignTokens.spacing20),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    device?.deviceType.toUpperCase() == 'WEB'
                        ? Icons.laptop
                        : Icons.smartphone,
                    size: 64,
                    color: theme.primaryColor,
                  ),
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              // Device Details Container
              Container(
                padding: const EdgeInsets.all(DesignTokens.spacing20),
                decoration: BoxDecoration(
                  color: theme.cardTheme.color,
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
                child: Column(
                  children: [
                    _buildInfoRow(context, 'Nombre', deviceName),
                    const Divider(height: 24),
                    _buildInfoRow(context, 'Tipo', device?.deviceType ?? 'MOBILE'),
                    const Divider(height: 24),
                    _buildInfoRow(context, 'Fabricante', device?.manufacturer ?? 'No disponible'),
                    const Divider(height: 24),
                    _buildInfoRow(context, 'Sistema / Versión', device?.osVersion ?? 'No disponible'),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      'Dispositivo actual',
                      device?.isCurrent == true ? 'Sí (Este dispositivo)' : 'No',
                      valueColor: device?.isCurrent == true ? theme.primaryColor : null,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      'Primer registro',
                      _formatDate(device?.firstSeenAt),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      'Último acceso',
                      _formatDate(device?.lastSeenAt),
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context,
                      'Estado',
                      statusLabel,
                      valueColor: statusColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: DesignTokens.spacing32),

              if (_isProcessing)
                const Center(child: CircularProgressIndicator())
              else ...[
                if (isPending && device != null) ...[
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacing16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                      ),
                    ),
                    onPressed: () => _approveDevice(device!),
                    child: const Text('Aprobar dispositivo como confiable'),
                  ),
                  const SizedBox(height: DesignTokens.spacing16),
                ],
                if (!isRevoked && device != null) ...[
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacing16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                      ),
                    ),
                    onPressed: () => _revokeDevice(device!),
                    child: const Text('Revocar acceso de este dispositivo'),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: DesignTokens.spacing12),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? theme.colorScheme.onSurface,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
