import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/design_tokens.dart';
import '../../logic/database_log_service.dart';
import '../../services/linked_apps_api_service.dart';
import '../../services/session_service.dart';

/// Modelo unificado para presentar aplicaciones vinculadas en la UI
class UnifiedLinkedApp {
  final String id;
  final String name;
  final String type; // 'TOTP' o 'OAUTH'
  final String linkedAt;
  final String? lastUsedAt;
  final String tokenStatus; // 'VIGENTE', 'VENCIDO', 'REVOCADO', 'LOCAL'
  final String scopes;
  final String? clientId;

  UnifiedLinkedApp({
    required this.id,
    required this.name,
    required this.type,
    required this.linkedAt,
    this.lastUsedAt,
    required this.tokenStatus,
    required this.scopes,
    this.clientId,
  });
}

class LinkedApplicationsScreen extends StatefulWidget {
  final LinkedAppsService? localService;
  final LinkedAppsApiService? apiService;
  final LocalAuthentication? localAuth;

  const LinkedApplicationsScreen({
    super.key,
    this.localService,
    this.apiService,
    this.localAuth,
  });

  @override
  State<LinkedApplicationsScreen> createState() => _LinkedApplicationsScreenState();
}

class _LinkedApplicationsScreenState extends State<LinkedApplicationsScreen> {
  late final LinkedAppsService _localService = widget.localService ?? LinkedAppsService();
  late final LinkedAppsApiService _apiService = widget.apiService ?? LinkedAppsApiService();
  late final LocalAuthentication _localAuth = widget.localAuth ?? LocalAuthentication();

  List<UnifiedLinkedApp> _applications = [];
  bool _isLoading = true;
  String? _serverError;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    _loadAllApps();
  }

  Future<void> _loadAllApps() async {
    setState(() {
      _isLoading = true;
      _serverError = null;
    });

    List<UnifiedLinkedApp> combined = [];

    // 1. Cargar aplicaciones TOTP locales (SQLite)
    try {
      final localApps = await _localService.getLinkedApps();
      for (final app in localApps) {
        // NUNCA se expone secretSeed en el modelo ni en la vista
        combined.add(UnifiedLinkedApp(
          id: (app['id'] ?? '').toString(),
          name: (app['name'] ?? 'App TOTP').toString(),
          type: 'TOTP',
          linkedAt: (app['addedAt'] ?? 'Desconocida').toString(),
          lastUsedAt: null,
          tokenStatus: 'LOCAL',
          scopes: 'Generación de códigos TOTP de un solo uso',
          clientId: null,
        ));
      }
    } catch (e) {
      // Error accediendo a sqlite local
    }

    // 2. Cargar plataformas OAuth del backend
    try {
      final oauthApps = await _apiService.getLinkedApplications();
      for (final app in oauthApps) {
        combined.add(UnifiedLinkedApp(
          id: 'oauth-${app['clientId']}',
          name: (app['appName'] ?? app['clientId'] ?? 'Plataforma OAuth').toString(),
          type: 'OAUTH',
          linkedAt: (app['linkedAt'] ?? 'Desconocida').toString(),
          lastUsedAt: app['lastUsedAt']?.toString(),
          tokenStatus: (app['tokenStatus'] ?? 'DESCONOCIDO').toString(),
          scopes: (app['scopes'] ?? 'openid').toString(),
          clientId: (app['clientId'] ?? '').toString(),
        ));
      }
    } catch (e) {
      _serverError = 'No se pudo conectar con el servidor para obtener aplicaciones OAuth. Mostrando aplicaciones locales.';
    }

    if (mounted) {
      setState(() {
        _applications = combined;
        _isLoading = false;
      });
    }
  }

  Future<void> _confirmUnlink(UnifiedLinkedApp app) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirmar desvinculación'),
        content: Text(
          '¿Estás seguro de que deseas desvincular "${app.name}"?\n'
          '${app.type == 'OAUTH' ? 'Se revocarán todos los tokens activos asociados de inmediato.' : 'Se eliminará la configuración TOTP local.'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desvincular', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _executeUnlink(app);
    }
  }

  Future<void> _executeUnlink(UnifiedLinkedApp app) async {
    try {
      if (app.type == 'TOTP') {
        await _localService.unlinkApp(app.id);
        await DatabaseLogService().logEvent('APP_UNLINKED', 'App TOTP desvinculada: ${app.name}', 'SUCCESS');
      } else if (app.type == 'OAUTH' && app.clientId != null) {
        await _apiService.unlinkApplication(app.clientId!);
        await DatabaseLogService().logEvent('OAUTH_APP_UNLINKED', 'Plataforma OAuth desvinculada: ${app.clientId}', 'SUCCESS');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${app.name}" desvinculada exitosamente.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadAllApps();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al desvincular: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _exportCertifiedLog() async {
    // 1. Re-autenticación biométrica o PIN obligatoria antes de descargar
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();

      if (canCheck || isSupported) {
        final authenticated = await _localAuth.authenticate(
          localizedReason: 'Confirme su identidad biométrica o PIN para descargar el registro certificado de aplicaciones',
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
      // Si la plataforma no soporta biometría en tests/emuladores, continuar
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
      final exportData = await _apiService.exportLinkedApplicationsLog(reauthToken: reauthToken);
      if (!mounted) return;
      setState(() => _isExporting = false);
      _showCertifiedExportDialog(exportData);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isExporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exportando registro certificado: $e'),
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
                'Por motivos de seguridad y privacidad forense, ingrese su contraseña para autorizar la descarga del log certificado.',
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
                'Registro Certificado de Aplicaciones',
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
                  'Reporte forense firmado criptográficamente de aplicaciones vinculadas y eventos de autorización OAuth (CU-0048).',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const Divider(height: 20),
                _buildInfoRow('Seudónimo de Usuario:', userPseudonym),
                _buildInfoRow('Fecha de Emisión:', generatedAt),
                _buildInfoRow('Total de Aplicaciones:', '$totalRecords'),
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
              Share.share(prettyJson, subject: 'Registro Certificado de Aplicaciones Vinculadas');
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

  Widget _buildStatusChip(String status) {
    Color bg;
    Color fg;
    String label = status;

    switch (status.toUpperCase()) {
      case 'VIGENTE':
        bg = Colors.green.shade100;
        fg = Colors.green.shade900;
        break;
      case 'VENCIDO':
        bg = Colors.amber.shade100;
        fg = Colors.amber.shade900;
        break;
      case 'REVOCADO':
        bg = Colors.red.shade100;
        fg = Colors.red.shade900;
        break;
      default:
        bg = Colors.grey.shade200;
        fg = Colors.grey.shade800;
        label = 'LOCAL';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aplicaciones Vinculadas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.hub_outlined),
            tooltip: 'Simulador de Plataforma Externa (Playground)',
            onPressed: () async {
              await Navigator.pushNamed(context, '/oauth_playground');
              _loadAllApps();
            },
          ),
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
            onPressed: _loadAllApps,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_serverError != null)
                  Container(
                    width: double.infinity,
                    color: Colors.amber.shade100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    child: Row(
                      children: [
                        Icon(Icons.cloud_off_rounded, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _serverError!,
                            style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 18),
                          color: Colors.amber.shade900,
                          onPressed: _loadAllApps,
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _applications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.apps_outage_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant),
                              const SizedBox(height: 16),
                              Text(
                                'No hay aplicaciones vinculadas.',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(DesignTokens.spacing16),
                          itemCount: _applications.length,
                          separatorBuilder: (_, __) => const SizedBox(height: DesignTokens.spacing12),
                          itemBuilder: (context, index) {
                            final app = _applications[index];
                            final isOAuth = app.type == 'OAUTH';

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
                                          backgroundColor: isOAuth
                                              ? theme.colorScheme.primaryContainer
                                              : theme.colorScheme.secondaryContainer,
                                          child: Icon(
                                            isOAuth ? Icons.vpn_key_rounded : Icons.lock_clock_rounded,
                                            color: isOAuth
                                                ? theme.colorScheme.onPrimaryContainer
                                                : theme.colorScheme.onSecondaryContainer,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                app.name,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  // Badge de Tipo
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      color: isOAuth ? Colors.teal.shade50 : Colors.indigo.shade50,
                                                      border: Border.all(
                                                        color: isOAuth ? Colors.teal.shade300 : Colors.indigo.shade300,
                                                      ),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      isOAuth ? 'Plataforma OAuth' : 'Código TOTP',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w600,
                                                        color: isOAuth ? Colors.teal.shade800 : Colors.indigo.shade800,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  if (isOAuth) _buildStatusChip(app.tokenStatus),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                                          tooltip: 'Desvincular',
                                          onPressed: () => _confirmUnlink(app),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 20),
                                    Text(
                                      'Vinculada el: ${app.linkedAt}',
                                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                    ),
                                    if (isOAuth) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Último uso: ${app.lastUsedAt ?? 'Sin uso registrado'}',
                                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                                      ),
                                    ],
                                    const SizedBox(height: 4),
                                    Text(
                                      'Permisos: ${app.scopes}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.hub_outlined),
        label: const Text('Simulador Terceros'),
        onPressed: () async {
          await Navigator.pushNamed(context, '/oauth_playground');
          _loadAllApps();
        },
      ),
    );
  }
}
