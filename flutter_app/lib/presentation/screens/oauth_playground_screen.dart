import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../core/database/app_database.dart';
import '../../core/security/local_crypto_helper.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/demo_mode_banner.dart';
import 'oauth_consent_screen.dart';

class OauthPlaygroundScreen extends StatefulWidget {
  const OauthPlaygroundScreen({super.key});

  @override
  State<OauthPlaygroundScreen> createState() => _OauthPlaygroundScreenState();
}

class _OauthPlaygroundScreenState extends State<OauthPlaygroundScreen> {
  List<Map<String, dynamic>> _issuedTokens = [];
  bool _isLoading = true;

  // Selección de plataforma demo
  String _selectedPlatformKey = 'casino';

  final Map<String, Map<String, String>> _demoPlatforms = {
    'casino': {
      'name': 'BetResponsable Online (Juego Responsable)',
      'clientId': 'client_casino_sip_01',
      'scope': 'read:profile,verify:age',
      'redirectUri': 'sipauth://playground/callback',
      'icon': 'casino',
    },
    'wallet': {
      'name': 'Billetera Digital Segura S.A.',
      'clientId': 'client_wallet_sip_02',
      'scope': 'verify:identity,read:profile',
      'redirectUri': 'sipauth://playground/callback',
      'icon': 'account_balance_wallet',
    },
    'academic': {
      'name': 'Portal Institucional USAL',
      'clientId': 'client_usal_sip_03',
      'scope': 'read:profile',
      'redirectUri': 'sipauth://playground/callback',
      'icon': 'school',
    },
  };

  @override
  void initState() {
    super.initState();
    _loadTokens();
  }

  Future<void> _loadTokens() async {
    setState(() => _isLoading = true);
    final tokens = await AppDatabase().getOAuthTokens();
    if (mounted) {
      setState(() {
        _issuedTokens = tokens;
        _isLoading = false;
      });
    }
  }

  Future<void> _launchConsentFlow() async {
    final platform = _demoPlatforms[_selectedPlatformKey]!;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OauthConsentScreen(
          clientId: platform['clientId']!,
          redirectUri: platform['redirectUri']!,
          state: 'state_${DateTime.now().millisecondsSinceEpoch}',
          nonce: 'nonce_${DateTime.now().millisecondsSinceEpoch}',
          codeChallenge: 'code_challenge_simulated',
          codeChallengeMethod: 'S256',
          scope: platform['scope']!,
        ),
      ),
    );

    if (result != null) {
      await _loadTokens();
    }
  }

  Future<void> _revokeToken(String tokenId) async {
    await AppDatabase().revokeOAuthToken(tokenId);
    await _loadTokens();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Token revocado y registrado en la bitácora criptográfica'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  Map<String, dynamic>? _decodeJwtPayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length >= 2) {
        String normalized = parts[1];
        while (normalized.length % 4 != 0) {
          normalized += '=';
        }
        final bytes = base64Url.decode(normalized);
        final decoded = utf8.decode(bytes);
        return jsonDecode(decoded) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  bool _verifyTokenSignature(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final content = '${parts[0]}.${parts[1]}';
        final expectedSignature = LocalCryptoHelper.hmacSha256Hex('SIP_LOCAL_OFFLINE_SECRET_KEY', content);
        return parts[2] == expectedSignature;
      }
    } catch (_) {}
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedPlatform = _demoPlatforms[_selectedPlatformKey]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma Externa Demo'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadTokens,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const DemoModeBanner(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Banner explicativo
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: theme.primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                        border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.hub_outlined, color: theme.primaryColor, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SIMULADOR DE INTEGRACIÓN EXTERNA (CU-0027)',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Permite demostrar al docente el flujo OAuth completo 100% offline: solicitud, consentimiento, emisión de token con CERO datos personales y posterior verificación/revocación.',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Selector de plataforma
                    Text('1. Plataforma Externa Solicitante', style: theme.textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            DropdownButtonFormField<String>(
                              value: _selectedPlatformKey,
                              decoration: const InputDecoration(
                                labelText: 'Seleccionar Tercero Integrador',
                                border: OutlineInputBorder(),
                              ),
                              items: _demoPlatforms.entries.map((entry) {
                                return DropdownMenuItem<String>(
                                  value: entry.key,
                                  child: Text(
                                    entry.value['name']!,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedPlatformKey = val);
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text('Client ID: ', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                Text(selectedPlatform['clientId']!, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text('Permisos solicitados: ', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold)),
                                Expanded(
                                  child: Text(selectedPlatform['scope']!, style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.lock_open_rounded),
                                label: const Text('Iniciar Flujo de Autorización OAuth'),
                                onPressed: _launchConsentFlow,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tokens emitidos
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('2. Tokens Emitidos (${_issuedTokens.length})', style: theme.textTheme.titleMedium),
                        if (_issuedTokens.isNotEmpty)
                          Text(
                            'CERO Datos Personales',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_isLoading)
                      const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
                    else if (_issuedTokens.isEmpty)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Center(
                            child: Text(
                              'Aún no se han emitido tokens. Presione "Iniciar Flujo de Autorización OAuth" para simular una emisión.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      ..._issuedTokens.map((tok) => _buildTokenCard(theme, tok)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenCard(ThemeData theme, Map<String, dynamic> tok) {
    final tokenId = tok['id'] as String;
    final clientId = tok['client_id'] as String;
    final tokenString = tok['token'] as String;
    final issuedAt = tok['issued_at'] as String;
    final expiresAt = tok['expires_at'] as String;
    final isRevoked = (tok['revoked'] as int) == 1;
    final scopes = tok['scopes'] as String;

    final claims = _decodeJwtPayload(tokenString);
    final isSignatureValid = _verifyTokenSignature(tokenString);

    String formattedIssued = issuedAt;
    String formattedExpires = expiresAt;
    try {
      formattedIssued = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(issuedAt));
      formattedExpires = DateFormat('dd/MM/yyyy HH:mm:ss').format(DateTime.parse(expiresAt));
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: isRevoked ? Colors.red.shade300 : Colors.green.shade300,
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      isRevoked ? Icons.cancel_outlined : Icons.check_circle_outline,
                      color: isRevoked ? Colors.red : Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      clientId,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isRevoked ? Colors.red.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isRevoked ? 'REVOCADO' : 'VIGENTE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isRevoked ? Colors.red.shade800 : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('Emitido: $formattedIssued', style: theme.textTheme.bodySmall),
            Text('Vence: $formattedExpires', style: theme.textTheme.bodySmall),
            Text('Permisos: $scopes', style: theme.textTheme.bodySmall),
            const Divider(height: 16),

            // Verificación criptográfica del token
            Row(
              children: [
                Icon(
                  isSignatureValid ? Icons.lock_outline : Icons.lock_open,
                  size: 14,
                  color: isSignatureValid ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  isSignatureValid
                      ? 'Firma criptográfica válida (Algoritmo RS256/HMAC)'
                      : 'Firma criptográfica INVÁLIDA',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSignatureValid ? Colors.green.shade700 : Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Claims Inspector (Proof of Zero PII)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                'Claims Criptográficos (Cero Datos Personales)',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.primaryColor,
                ),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: SelectableText(
                    claims != null
                        ? const JsonEncoder.withIndent('  ').convert(claims)
                        : 'No se pudo decodificar payload',
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copiar Token', style: TextStyle(fontSize: 11)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: tokenString));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Token copiado al portapapeles'), duration: Duration(seconds: 1)),
                    );
                  },
                ),
                if (!isRevoked) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.block, size: 14),
                    label: const Text('Revocar Token', style: TextStyle(fontSize: 11)),
                    onPressed: () => _revokeToken(tokenId),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
