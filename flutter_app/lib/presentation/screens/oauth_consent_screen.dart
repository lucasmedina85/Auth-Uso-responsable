import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../../core/network/dio_client.dart';
import '../../core/theme/design_tokens.dart';
import '../widgets/buttons.dart';

class OauthConsentScreen extends StatefulWidget {
  final String clientId;
  final String redirectUri;
  final String state;
  final String? nonce;
  final String codeChallenge;
  final String codeChallengeMethod;
  final String scope;
  final Future<Map<String, dynamic>> Function(String clientId, String redirectUri)? clientInfoFetcher;
  final Future<Map<String, dynamic>> Function(Map<String, dynamic> body)? tokenExchangeHandler;

  const OauthConsentScreen({
    super.key,
    required this.clientId,
    required this.redirectUri,
    required this.state,
    this.nonce,
    required this.codeChallenge,
    this.codeChallengeMethod = 'S256',
    required this.scope,
    this.clientInfoFetcher,
    this.tokenExchangeHandler,
  });

  @override
  State<OauthConsentScreen> createState() => _OauthConsentScreenState();
}

class _OauthConsentScreenState extends State<OauthConsentScreen> {
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  String? _verifiedClientName;
  String? _validatedRedirectUri;

  @override
  void initState() {
    super.initState();
    _validateClientAntiPhishing();
  }

  Future<void> _validateClientAntiPhishing() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (widget.clientInfoFetcher != null) {
        final data = await widget.clientInfoFetcher!(widget.clientId, widget.redirectUri);
        setState(() {
          _verifiedClientName = data['clientName']?.toString() ?? 'Plataforma Externa';
          _validatedRedirectUri = data['redirectUri']?.toString() ?? widget.redirectUri;
          _isLoading = false;
        });
        return;
      }

      final dio = DioClient().dio;
      final response = await dio.get(
        '/oauth/client-info',
        queryParameters: {
          'client_id': widget.clientId,
          'redirect_uri': widget.redirectUri,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        setState(() {
          _verifiedClientName = data['clientName']?.toString() ?? 'Plataforma Externa';
          _validatedRedirectUri = data['redirectUri']?.toString() ?? widget.redirectUri;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Respuesta inesperada al validar la plataforma.';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      final desc = e.response?.data is Map
          ? (e.response?.data['error_description']?.toString() ?? 'Validación de cliente rechazada')
          : 'No se pudo verificar la autenticidad de la plataforma externa solicitante.';
      setState(() {
        _errorMessage = desc;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Error de conexión al validar la plataforma solicitante.';
        _isLoading = false;
      });
    }
  }

  Future<void> _handleAuthorize() async {
    if (_validatedRedirectUri == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      String? code;
      String? state;

      if (widget.tokenExchangeHandler != null) {
        final data = await widget.tokenExchangeHandler!({
          'clientId': widget.clientId,
          'redirectUri': _validatedRedirectUri,
          'state': widget.state,
          'nonce': widget.nonce,
          'codeChallenge': widget.codeChallenge,
          'codeChallengeMethod': widget.codeChallengeMethod,
          'scope': widget.scope,
          'consentGiven': true,
        });
        code = data['code']?.toString();
        state = data['state']?.toString() ?? widget.state;
      } else {
        final dio = DioClient().dio;
        final response = await dio.post(
          '/oauth/token-exchange',
          data: {
            'clientId': widget.clientId,
            'redirectUri': _validatedRedirectUri,
            'state': widget.state,
            'nonce': widget.nonce,
            'codeChallenge': widget.codeChallenge,
            'codeChallengeMethod': widget.codeChallengeMethod,
            'scope': widget.scope,
            'consentGiven': true,
          },
        );

        if (response.statusCode == 200 && response.data != null) {
          code = response.data['code']?.toString();
          state = response.data['state']?.toString() ?? widget.state;
        }
      }

      if (code != null) {
        
        final parsedUri = Uri.parse(_validatedRedirectUri!);
        final returnUri = parsedUri.replace(
          queryParameters: {
            ...parsedUri.queryParameters,
            'code': code.toString(),
            'state': state.toString(),
          },
        );

        await launchUrl(returnUri, mode: LaunchMode.externalApplication);
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } on DioException catch (e) {
      final desc = e.response?.data is Map
          ? (e.response?.data['error_description']?.toString() ?? 'Error al intercambiar token')
          : 'Ocurrió un error al autorizar la solicitud.';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(desc), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error inesperado al autorizar.'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _handleReject() async {
    if (_validatedRedirectUri != null) {
      final parsedUri = Uri.parse(_validatedRedirectUri!);
      final rejectUri = parsedUri.replace(
        queryParameters: {
          ...parsedUri.queryParameters,
          'error': 'access_denied',
          'state': widget.state,
        },
      );
      await launchUrl(rejectUri, mode: LaunchMode.externalApplication);
    }

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text('Autorización de Acceso', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(DesignTokens.spacing24),
          child: _isLoading
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColorsLight.primary),
                      SizedBox(height: 16),
                      Text(
                        'Verificando legitimidad de la plataforma...',
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              : _errorMessage != null
                  ? _buildAntiPhishingErrorView()
                  : _buildConsentFormView(),
        ),
      ),
    );
  }

  Widget _buildAntiPhishingErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gpp_bad, color: Colors.redAccent, size: 72),
          const SizedBox(height: 16),
          const Text(
            'Solicitud no verificada',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'La plataforma o dirección de retorno no está autorizada.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 24),
          const Card(
            color: Color(0xFF2A1515),
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.orangeAccent),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Por protección anti-phishing, la app no compartirá datos ni abrirá enlaces no certificados.',
                      style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          PrimaryButton(
            text: 'Cerrar y Volver',
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildConsentFormView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColorsLight.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user, color: AppColorsLight.primary, size: 48),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '¿Autorizás a ${_verifiedClientName ?? widget.clientId}?',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'La plataforma solicita comprobar tu condición para habilitar tu cuenta.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2638),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DATOS A COMPARTIR:',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        SizedBox(height: 12),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Mayor de edad verificado (+18 años)',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        Divider(color: Colors.white10),
                        SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.lock_outline, color: AppColorsLight.primary, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Privacidad protegida: NO se compartirá tu nombre, DNI, fecha de nacimiento, fotos ni domicilio.',
                                style: TextStyle(color: Colors.white70, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    text: 'Autorizar y Continuar',
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _handleAuthorize,
                  ),
                  const SizedBox(height: 12),
                  SecondaryButton(
                    text: 'Rechazar',
                    onPressed: _isSubmitting ? null : _handleReject,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
