import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';
import '../../services/session_service.dart';
import '../../services/user_activity_api_service.dart';

class DeviceActivityTimelineScreen extends StatefulWidget {
  final UserActivityApiService? apiService;
  final LocalAuthentication? localAuth;

  const DeviceActivityTimelineScreen({
    super.key,
    this.apiService,
    this.localAuth,
  });

  @override
  State<DeviceActivityTimelineScreen> createState() => _DeviceActivityTimelineScreenState();
}

class _DeviceActivityTimelineScreenState extends State<DeviceActivityTimelineScreen> {
  late final UserActivityApiService _apiService = widget.apiService ?? UserActivityApiService();
  late final LocalAuthentication _localAuth = widget.localAuth ?? LocalAuthentication();
  final ScrollController _scrollController = ScrollController();

  List<Map<String, dynamic>> _events = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  bool _isExporting = false;

  // Filtros
  String _selectedType = 'ALL';
  DateTimeRange? _selectedDateRange;

  // Paginación
  int _currentPage = 0;
  final int _pageSize = 20;
  bool _hasNext = false;
  int _totalElements = 0;

  final List<Map<String, String>> _typeFilters = [
    {'key': 'ALL', 'label': 'Todos'},
    {'key': 'LOGIN', 'label': 'Logins'},
    {'key': 'VALIDATION', 'label': 'Validaciones'},
    {'key': 'DEVICE', 'label': 'Dispositivos'},
    {'key': 'OAUTH', 'label': 'OAuth'},
    {'key': 'SECURITY', 'label': 'Seguridad'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadEvents(page: 0, append: false);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (_hasNext && !_isLoading && !_isLoadingMore) {
        _loadEvents(page: _currentPage + 1, append: true);
      }
    }
  }

  Future<void> _loadEvents({required int page, required bool append}) async {
    if (!append) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    } else {
      setState(() {
        _isLoadingMore = true;
      });
    }

    try {
      final startDateStr = _selectedDateRange?.start.toIso8601String().substring(0, 10);
      final endDateStr = _selectedDateRange?.end.toIso8601String().substring(0, 10);

      final response = await _apiService.getUserActivity(
        page: page,
        size: _pageSize,
        type: _selectedType,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      final rawEvents = response['events'] as List? ?? [];
      final parsedEvents = rawEvents.map((e) => Map<String, dynamic>.from(e as Map)).toList();

      if (mounted) {
        setState(() {
          if (append) {
            _events.addAll(parsedEvents);
          } else {
            _events = parsedEvents;
          }
          _currentPage = (response['page'] ?? page) as int;
          _hasNext = (response['hasNext'] ?? false) as bool;
          _totalElements = (response['totalElements'] ?? _events.length) as int;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Error al cargar actividades: $e';
        });
      }
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now,
      initialDateRange: _selectedDateRange ?? DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
      helpText: 'Filtrar por rango de fechas',
      cancelText: 'Cancelar',
      confirmText: 'Aplicar',
    );

    if (picked != null) {
      setState(() {
        _selectedDateRange = picked;
      });
      _loadEvents(page: 0, append: false);
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDateRange = null;
    });
    _loadEvents(page: 0, append: false);
  }

  Future<void> _exportCertifiedLog() async {
    // 1. Re-autenticación biométrica o PIN obligatoria antes de descargar
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (canCheck || isSupported) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirme su identidad biométrica o PIN para descargar el registro certificado de actividad',
          options: const AuthenticationOptions(
            biometricOnly: false,
            stickyAuth: true,
          ),
        );
        if (!authenticated) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Autenticación cancelada. No se descargó el registro.'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }
    } catch (e) {
      // Ignorar en entornos sin sensor biométrico
    }

    // 2. Solicitar contraseña en memoria para generar token de un solo uso en servidor (Punto 1)
    final password = await _promptPasswordDialog(context);
    if (password == null || password.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Operación cancelada: contraseña requerida para autorizar exportación.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    setState(() => _isExporting = true);

    String? reauthToken;
    try {
      reauthToken = await SessionService.requestReauthToken(password);
      if (reauthToken == null) {
        throw Exception('No se pudo obtener el token de autorización de exportación');
      }

      final startDateStr = _selectedDateRange?.start.toIso8601String().substring(0, 10);
      final endDateStr = _selectedDateRange?.end.toIso8601String().substring(0, 10);

      final exportData = await _apiService.exportUserActivity(
        reauthToken: reauthToken,
        startDate: startDateStr,
        endDate: endDateStr,
      );

      if (!mounted) return;
      setState(() => _isExporting = false);
      _showCertifiedExportDialog(exportData);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando registro de actividad: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // Descartar inmediatamente de memoria el token de reautenticación
      reauthToken = null;
    }
  }

  Future<String?> _promptPasswordDialog(BuildContext context) async {
    final controller = TextEditingController();
    bool obscure = true;
    final res = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.shield_rounded, color: Colors.blueGrey),
              SizedBox(width: 8),
              Expanded(
                child: Text('Confirmar Contraseña', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Por motivos de seguridad y privacidad forense, ingrese su contraseña para autorizar la exportación de actividad.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscure,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña de la cuenta',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setDlgState(() => obscure = !obscure),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, controller.text),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return res;
  }

  void _showCertifiedExportDialog(Map<String, dynamic> data) {
    final theme = Theme.of(context);
    final String integrityHash = (data['integrityHashSha256'] ?? 'N/A').toString();
    final String signature = (data['signature'] ?? 'N/A').toString();
    final String algorithm = (data['signingAlgorithm'] ?? 'SHA256withRSA').toString();
    final payload = data['payload'] as Map<String, dynamic>? ?? {};
    final String userPseudonym = (payload['userPseudonym'] ?? 'N/A').toString();
    final String dateRange = (payload['dateRange'] ?? 'N/A').toString();
    final String generatedAt = (payload['generatedAt'] ?? 'N/A').toString();
    final int totalRecords = (payload['totalRecords'] ?? 0) as int;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.verified_user_rounded, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Registro Certificado de Actividad',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Reporte forense firmado criptográficamente de eventos de auditoría, blockchain y accesos de cuenta (CU-0048).',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Divider(height: 20),
                _buildInfoRow('Seudónimo de Usuario:', userPseudonym),
                _buildInfoRow('Período:', dateRange),
                _buildInfoRow('Fecha de Emisión:', generatedAt),
                _buildInfoRow('Total de Eventos:', '$totalRecords'),
                _buildInfoRow('Algoritmo de Firma:', algorithm),
                const SizedBox(height: 12),
                Text(
                  'Hash de Integridad (SHA-256):',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SelectableText(
                          integrityHash,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copiar Hash',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: integrityHash));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Hash copiado al portapapeles')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Firma Digital RSA (RS256):',
                  style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          signature.length > 32 ? '${signature.substring(0, 32)}...' : signature,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 18),
                        tooltip: 'Copiar Firma',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: signature));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Firma copiada al portapapeles')),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.share_rounded, size: 18),
            label: const Text('Compartir Log'),
            onPressed: () {
              Navigator.pop(ctx);
              final prettyJson = const JsonEncoder.withIndent('  ').convert(data);
              Share.share(prettyJson, subject: 'Registro Certificado de Actividad');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          Text(value, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  IconData _getEventIcon(String type) {
    switch (type.toUpperCase()) {
      case 'LOGIN':
        return Icons.login_rounded;
      case 'VALIDATION':
        return Icons.verified_user_outlined;
      case 'DEVICE':
        return Icons.devices_rounded;
      case 'OAUTH':
        return Icons.vpn_key_rounded;
      case 'SECURITY':
        return Icons.shield_outlined;
      default:
        return Icons.event_note_rounded;
    }
  }

  Widget _buildResultBadge(String? result, String? decision) {
    final status = (result ?? decision ?? 'INFO').toUpperCase();
    Color bg = Colors.grey.shade200;
    Color fg = Colors.grey.shade800;

    if (status.contains('SUCCESS') || status == 'AUTORIZAR' || status == 'ACTIVO') {
      bg = Colors.green.shade100;
      fg = Colors.green.shade900;
    } else if (status.contains('BLOCK') || status == 'BLOQUEAR' || status == 'REVOCADO') {
      bg = Colors.red.shade100;
      fg = Colors.red.shade900;
    } else if (status.contains('REVIEW') || status == 'REVISIÓN' || status == 'ALERT') {
      bg = Colors.amber.shade100;
      fg = Colors.amber.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad de la Cuenta'),
        actions: [
          IconButton(
            icon: _isExporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Exportar Log Certificado',
            onPressed: _isExporting ? null : _exportCertifiedLog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: () => _loadEvents(page: 0, append: false),
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de Filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            child: Column(
              children: [
                // Chips de Tipo
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _typeFilters.map((f) {
                      final isSelected = _selectedType == f['key'];
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(f['label']!),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              _selectedType = f['key']!;
                            });
                            _loadEvents(page: 0, append: false);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 6),
                // Filtro de Rango de Fechas
                Row(
                  children: [
                    Icon(Icons.calendar_today_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      _selectedDateRange != null
                          ? '${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM/yyyy').format(_selectedDateRange!.end)}'
                          : 'Todas las fechas',
                      style: theme.textTheme.bodySmall,
                    ),
                    const Spacer(),
                    if (_selectedDateRange != null)
                      TextButton(
                        onPressed: _clearDateFilter,
                        child: const Text('Limpiar', style: TextStyle(fontSize: 12)),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.date_range_rounded, size: 14),
                      label: const Text('Filtrar Fechas', style: TextStyle(fontSize: 12)),
                      onPressed: _pickDateRange,
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Lista de Eventos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, size: 48, color: Colors.red.shade400),
                              const SizedBox(height: 12),
                              Text(_errorMessage!, textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: () => _loadEvents(page: 0, append: false),
                                child: const Text('Reintentar'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _events.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.history_toggle_off_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant),
                                const SizedBox(height: 16),
                                Text(
                                  'No hay actividades registradas.',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Pruebe cambiando los filtros de tipo o fecha.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(DesignTokens.spacing16),
                            itemCount: _events.length + (_hasNext ? 1 : 0),
                            separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spacing12),
                            itemBuilder: (context, index) {
                              if (index >= _events.length) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: _isLoadingMore
                                        ? const CircularProgressIndicator()
                                        : ElevatedButton(
                                            onPressed: () => _loadEvents(page: _currentPage + 1, append: true),
                                            child: const Text('Cargar más actividades'),
                                          ),
                                  ),
                                );
                              }

                              final ev = _events[index];
                              final type = (ev['type'] ?? 'EVENT').toString();
                              final timestamp = (ev['timestamp'] ?? '').toString();
                              final description = (ev['description'] ?? 'Actividad de cuenta').toString();
                              final result = ev['result']?.toString();
                              final decision = ev['decision']?.toString();
                              final maskedIp = ev['maskedIp']?.toString();
                              final txRef = ev['txRef']?.toString();

                              return Card(
                                elevation: 1,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: const EdgeInsets.all(DesignTokens.spacing16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          CircleAvatar(
                                            backgroundColor: theme.colorScheme.primaryContainer,
                                            child: Icon(_getEventIcon(type), color: theme.colorScheme.onPrimaryContainer),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  description,
                                                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  timestamp,
                                                  style: theme.textTheme.bodySmall?.copyWith(
                                                    color: theme.colorScheme.onSurfaceVariant,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildResultBadge(result, decision),
                                        ],
                                      ),
                                      if (maskedIp != null && maskedIp.isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.public_rounded, size: 14, color: theme.colorScheme.onSurfaceVariant),
                                            const SizedBox(width: 4),
                                            Text(
                                              'IP: $maskedIp',
                                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                            ),
                                          ],
                                        ),
                                      ],
                                      if (txRef != null && txRef.isNotEmpty) ...[
                                        const SizedBox(height: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.blueGrey.shade50,
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: Colors.blueGrey.shade200),
                                          ),
                                          child: Row(
                                            children: [
                                              Icon(Icons.token_rounded, size: 14, color: Colors.blueGrey.shade800),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  'Tx Blockchain: $txRef',
                                                  style: TextStyle(
                                                    fontFamily: 'monospace',
                                                    fontSize: 11,
                                                    color: Colors.blueGrey.shade900,
                                                  ),
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.copy, size: 14),
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                                tooltip: 'Copiar referencia Tx',
                                                onPressed: () {
                                                  Clipboard.setData(ClipboardData(text: txRef));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Referencia Tx copiada')),
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
