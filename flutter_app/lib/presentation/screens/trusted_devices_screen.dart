import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/theme/design_tokens.dart';
import '../../models/device_model.dart';
import '../../services/device_management_service.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import '../widgets/buttons.dart';

class TrustedDevicesScreen extends StatefulWidget {
  const TrustedDevicesScreen({super.key});

  @override
  State<TrustedDevicesScreen> createState() => _TrustedDevicesScreenState();
}

class _TrustedDevicesScreenState extends State<TrustedDevicesScreen> {
  final DeviceManagementService _deviceService = DeviceManagementService();
  List<DeviceModel> _devices = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  Future<void> _loadDevices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _deviceService.getDevices();
      if (mounted) {
        setState(() {
          _devices = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No se pudieron cargar los dispositivos.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _registerCurrentDevice() async {
    setState(() => _isLoading = true);
    try {
      final newDevice = await _deviceService.registerCurrentDevice();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newDevice?.status == 'TRUSTED'
                  ? 'Dispositivo registrado como confiable.'
                  : 'Dispositivo registrado. Pendiente de aprobación.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al registrar el dispositivo actual.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _approveDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aprobar dispositivo'),
        content: Text('¿Deseas autorizar "${device.deviceName}" como dispositivo de confianza?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aprobar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _deviceService.approveDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispositivo "${device.deviceName}" aprobado.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al aprobar el dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeDevice(DeviceModel device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revocar dispositivo'),
        content: Text('¿Estás seguro de que deseas revocar el acceso a "${device.deviceName}"?'),
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

    try {
      await _deviceService.revokeDevice(device.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dispositivo "${device.deviceName}" revocado.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al revocar el dispositivo.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Desconocida';
    return DateFormat('dd/MM/yyyy, HH:mm').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCurrentDevice = _devices.any((d) => d.isCurrent);
    final currentIsTrusted = _devices.any((d) => d.isCurrent && d.status == 'TRUSTED');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dispositivos Confiables'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadDevices,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadDevices,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: DesignTokens.spacing16),
                          Text(_errorMessage!, style: theme.textTheme.bodyMedium),
                          const SizedBox(height: DesignTokens.spacing16),
                          ElevatedButton(
                            onPressed: _loadDevices,
                            child: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: DesignTokens.spacing20,
                        vertical: DesignTokens.spacing20,
                      ),
                      children: [
                        Text(
                          'Gestiona los dispositivos autorizados para acceder a tu cuenta.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spacing24),

                        // Banner si este dispositivo no está registrado
                        if (!hasCurrentDevice) ...[
                          Container(
                            padding: const EdgeInsets.all(DesignTokens.spacing16),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                              border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.phonelink_setup, color: theme.primaryColor),
                                    const SizedBox(width: DesignTokens.spacing12),
                                    Expanded(
                                      child: Text(
                                        'Este dispositivo no está registrado',
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: DesignTokens.spacing8),
                                Text(
                                  'Registrá este equipo para operar de forma segura y autorizar otros dispositivos.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: DesignTokens.spacing12),
                                PrimaryButton(
                                  text: 'Registrar este dispositivo',
                                  onPressed: _registerCurrentDevice,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing24),
                        ],

                        // Estado vacío
                        if (_devices.isEmpty) ...[
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: DesignTokens.spacing32),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.devices_other,
                                    size: 64,
                                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  ),
                                  const SizedBox(height: DesignTokens.spacing16),
                                  Text(
                                    'No tienes dispositivos vinculados',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: DesignTokens.spacing8),
                                  Text(
                                    'Al registrar tu primer dispositivo tras validar tu identidad, quedará habilitado como dispositivo de confianza.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: DesignTokens.spacing24),
                                  PrimaryButton(
                                    text: 'Registrar este dispositivo',
                                    onPressed: _registerCurrentDevice,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Tus Dispositivos (${_devices.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: DesignTokens.spacing16),
                          ..._devices.map((device) => _buildDeviceCard(
                                context,
                                device,
                                currentIsTrusted: currentIsTrusted,
                              )),
                        ],
                      ],
                    ),
        ),
      ),
      bottomNavigationBar: const SharedBottomNavBar(
        currentIndex: 0,
      ),
    );
  }

  Widget _buildDeviceCard(BuildContext context, DeviceModel device, {required bool currentIsTrusted}) {
    final theme = Theme.of(context);
    final isRevoked = device.status == 'REVOKED';
    final isPending = device.status == 'PENDING';

    IconData icon = Icons.smartphone;
    if (device.deviceType.toUpperCase() == 'WEB') icon = Icons.laptop;

    return Card(
      margin: const EdgeInsets.only(bottom: DesignTokens.spacing16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(DesignTokens.radiusLarge),
        side: BorderSide(
          color: device.isCurrent
              ? theme.primaryColor.withOpacity(0.5)
              : theme.colorScheme.outlineVariant,
        ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              device.deviceName,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (device.isCurrent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.primaryColor.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(DesignTokens.radiusSmall),
                              ),
                              child: Text(
                                'Este dispositivo',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.primaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        '${device.manufacturer ?? ''} ${device.osVersion ?? device.deviceType}'.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: DesignTokens.spacing16),

            _buildDetailRow(theme, 'Primer acceso:', _formatDateTime(device.firstSeenAt)),
            _buildDetailRow(theme, 'Último acceso:', _formatDateTime(device.lastSeenAt)),

            const SizedBox(height: DesignTokens.spacing8),

            _buildStatusBadge(theme, device.status),

            const SizedBox(height: DesignTokens.spacing16),

            // Acciones disponibles
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    text: 'Detalles',
                    onPressed: () {
                      Navigator.pushNamed(
                        context,
                        '/device_details',
                        arguments: device,
                      ).then((_) => _loadDevices());
                    },
                  ),
                ),
                if (isPending && currentIsTrusted) ...[
                  const SizedBox(width: DesignTokens.spacing8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => _approveDevice(device),
                      child: const Text('Aprobar'),
                    ),
                  ),
                ],
                if (!isRevoked) ...[
                  const SizedBox(width: DesignTokens.spacing8),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Revocar acceso',
                    onPressed: () => _revokeDevice(device),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(ThemeData theme, String label, String value) {
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
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, String status) {
    Color badgeColor = AppColorsLight.success;
    String statusLabel = 'Confiable';
    IconData statusIcon = Icons.check_circle;

    if (status == 'PENDING') {
      badgeColor = AppColorsLight.warning;
      statusLabel = 'Pendiente de aprobación';
      statusIcon = Icons.pending_actions;
    } else if (status == 'REVOKED') {
      badgeColor = AppColorsLight.error;
      statusLabel = 'Acceso revocado';
      statusIcon = Icons.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: badgeColor),
          const SizedBox(width: 6),
          Text(
            statusLabel,
            style: theme.textTheme.labelSmall?.copyWith(
              color: badgeColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
