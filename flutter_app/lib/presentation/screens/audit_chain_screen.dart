import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/demo_mode_banner.dart';

class AuditChainScreen extends StatefulWidget {
  const AuditChainScreen({super.key});

  @override
  State<AuditChainScreen> createState() => _AuditChainScreenState();
}

class _AuditChainScreenState extends State<AuditChainScreen> {
  List<Map<String, dynamic>> _chain = [];
  bool _isLoading = true;
  bool? _isChainValid;
  String? _verificationMessage;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _loadChainAndVerify();
  }

  Future<void> _loadChainAndVerify() async {
    setState(() {
      _isLoading = true;
    });

    final chain = await AppDatabase().getAuditChain();
    final isValid = await AppDatabase().verifyChainIntegrity();

    if (mounted) {
      setState(() {
        _chain = chain;
        _isChainValid = isValid;
        _isLoading = false;
        _verificationMessage = isValid
            ? 'Integridad criptográfica verificada: ${chain.length} eslabones encadenados sin alteraciones.'
            : '¡ALERTA DE SEGURIDAD! Se detectó una inconsistencia o alteración en la cadena de auditoría.';
      });
    }
  }

  Future<void> _runManualVerification() async {
    setState(() {
      _isVerifying = true;
    });

    await Future.delayed(const Duration(milliseconds: 400));
    final isValid = await AppDatabase().verifyChainIntegrity();
    final chain = await AppDatabase().getAuditChain();

    if (mounted) {
      setState(() {
        _chain = chain;
        _isChainValid = isValid;
        _isVerifying = false;
        _verificationMessage = isValid
            ? 'Verificación completada: Los ${chain.length} bloques coinciden exactamente con sus firmas SHA-256.'
            : 'Fallo de integridad: Al menos un bloque no coincide con su hash o el hash previo está roto.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isValid
                ? 'Cadena 100% íntegra y verificada.'
                : 'Inconsistencia detectada en la cadena.',
          ),
          backgroundColor: isValid ? Colors.green.shade700 : Colors.red.shade700,
        ),
      );
    }
  }

  Future<void> _addSampleAuditEvent() async {
    await AppDatabase().addAuditEvent('MANUAL_DEMO_VERIFICATION', {
      'source': 'DOCENTE_DEMO',
      'note': 'Evento de auditoría registrado manualmente durante la demostración',
      'evaluatedAt': DateTime.now().toIso8601String(),
    });
    await _loadChainAndVerify();
  }

  Future<void> _simulateTamperAttack() async {
    if (_chain.length <= 1) {
      await _addSampleAuditEvent();
    }
    // Alterar payload del bloque 1
    await AppDatabase().tamperChainForTesting(1, '{"altered": true, "attacker": "MODIFICADO_SIN_PERMISO"}');
    await _loadChainAndVerify();
  }

  Future<void> _restoreChain() async {
    await AppDatabase().resetForDemo();
    await _loadChainAndVerify();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bitácora Criptográfica'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: _isVerifying
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.verified_outlined),
            tooltip: 'Verificar Integridad',
            onPressed: _isVerifying ? null : _runManualVerification,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: _loadChainAndVerify,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoModeBanner(),
            _buildStatusHeader(theme),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _chain.isEmpty
                      ? const Center(child: Text('No hay registros en la cadena'))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _chain.length,
                          itemBuilder: (context, index) {
                            final block = _chain[index];
                            final isFirst = index == 0;
                            final isLast = index == _chain.length - 1;
                            return _buildBlockCard(theme, block, isFirst, isLast);
                          },
                        ),
            ),
            _buildActionFooter(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(ThemeData theme) {
    final isValid = _isChainValid ?? false;
    final color = isValid ? Colors.green : Colors.red;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isValid ? Icons.verified_user_rounded : Icons.warning_amber_rounded,
            color: color.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isValid ? 'CADENA VÁLIDA (CU-0050)' : 'CADENA COMPROMETIDA',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: color.shade800,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _verificationMessage ?? 'Calculando integridad criptográfica...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlockCard(
    ThemeData theme,
    Map<String, dynamic> block,
    bool isFirst,
    bool isLast,
  ) {
    final int index = block['chain_index'] as int;
    final String eventType = block['event_type'] as String;
    final String timestamp = block['timestamp'] as String;
    final String prevHash = block['prev_hash'] as String;
    final String hash = block['hash'] as String;
    final String payload = block['payload'] as String;

    String formattedDate = timestamp;
    try {
      final parsed = DateTime.parse(timestamp);
      formattedDate = DateFormat('dd/MM/yyyy HH:mm:ss').format(parsed);
    } catch (_) {}

    final isGenesis = index == 0;

    return Column(
      children: [
        Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(
              color: isGenesis ? theme.primaryColor : theme.colorScheme.outlineVariant,
              width: isGenesis ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isGenesis
                              ? theme.primaryColor
                              : theme.colorScheme.secondaryContainer,
                          child: Text(
                            '$index',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isGenesis
                                  ? Colors.white
                                  : theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isGenesis ? 'Bloque Génesis' : 'Bloque #$index',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        eventType,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: theme.primaryColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Fecha: $formattedDate',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 16),
                Text(
                  'Hash previo (prev_hash):',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                _buildHashBox(theme, prevHash),
                const SizedBox(height: 8),
                Text(
                  'Hash de este bloque (hash):',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                _buildHashBox(theme, hash, highlight: true),
                const SizedBox(height: 10),
                ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  title: Text(
                    'Carga útil (Payload JSON)',
                    style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: SelectableText(
                        _prettifyJson(payload),
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        if (!isLast)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Icon(Icons.arrow_downward, size: 18, color: theme.colorScheme.onSurfaceVariant),
                Text(
                  'prev_hash == hash anterior',
                  style: TextStyle(
                    fontSize: 9,
                    fontStyle: FontStyle.italic,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildHashBox(ThemeData theme, String hash, {bool highlight = false}) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: highlight
            ? theme.primaryColor.withOpacity(0.08)
            : theme.colorScheme.surfaceVariant.withOpacity(0.4),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: highlight ? theme.primaryColor.withOpacity(0.3) : theme.colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SelectableText(
              hash,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 10,
                color: highlight ? theme.primaryColor : theme.colorScheme.onSurface,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          InkWell(
            onTap: () {
              Clipboard.setData(ClipboardData(text: hash));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Hash copiado al portapapeles'), duration: Duration(seconds: 1)),
              );
            },
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.copy, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionFooter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_circle_outline, size: 16),
              label: const Text('Nuevo Evento', style: TextStyle(fontSize: 12)),
              onPressed: _addSampleAuditEvent,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.verified, size: 16),
              label: const Text('Verificar', style: TextStyle(fontSize: 12)),
              onPressed: _runManualVerification,
            ),
          ),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'Opciones de Demostración',
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'TAMPER') {
                _simulateTamperAttack();
              } else if (value == 'RESTORE') {
                _restoreChain();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'TAMPER',
                child: Text('Simular Alteración (Ataque)'),
              ),
              const PopupMenuItem(
                value: 'RESTORE',
                child: Text('Restaurar Cadena Demo'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _prettifyJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      return const JsonEncoder.withIndent('  ').convert(decoded);
    } catch (_) {
      return rawJson;
    }
  }
}
