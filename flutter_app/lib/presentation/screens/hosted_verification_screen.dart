import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class HostedVerificationScreen extends StatefulWidget {
  const HostedVerificationScreen({Key? key}) : super(key: key);

  @override
  State<HostedVerificationScreen> createState() => _HostedVerificationScreenState();
}

class _HostedVerificationScreenState extends State<HostedVerificationScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  String? _sessionId;
  Timer? _pollingTimer;

  // TODO: Leer desde .env o Config
  final String _backendUrl = 'http://10.0.2.2:8080/api/v1/verification';

  Future<void> _startVerification() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_backendUrl/start'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'userId': 'current-user-id'}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _sessionId = data['sessionId'];
        final url = data['url'];

        if (url != null && await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          _startPolling();
        } else {
          setState(() => _errorMessage = 'No se pudo abrir la URL de verificación.');
        }
      } else {
        setState(() => _errorMessage = 'Servicio de verificación en mantenimiento.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error de red. Intente nuevamente.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_sessionId == null) return;
      
      try {
        final response = await http.get(Uri.parse('$_backendUrl/session/$_sessionId'));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final matchType = data['matchType'];
          
          if (matchType == 'APPROVED' || matchType == 'FULL_MATCH') {
            timer.cancel();
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/fingerprint');
            }
          } else if (matchType == 'REJECTED' || matchType == 'NO_MATCH') {
            timer.cancel();
            setState(() {
              _errorMessage = 'Identidad no verificada. Por favor, vuelva a intentarlo.';
            });
          } else if (matchType == 'ABANDONED' || matchType == 'EXPIRED') {
            timer.cancel();
            setState(() {
              _errorMessage = 'El proceso ha expirado o fue cancelado.';
            });
          }
        }
        // 204 No Content means still pending, keep polling
      } catch (e) {
        // Ignorar errores de red temporales durante el polling
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verificación de Identidad')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 64, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'Validación con Renaper',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'Serás redirigido a un portal seguro para escanear tu DNI y rostro.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 32),
              if (_errorMessage != null) ...[
                Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 16),
              ],
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_sessionId == null || _errorMessage != null)
                ElevatedButton(
                  onPressed: _startVerification,
                  child: const Text('Iniciar Verificación Seguro'),
                )
              else
                const Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Esperando validación... Podés volver aquí luego de terminar en el navegador.', textAlign: TextAlign.center)
                  ]
                )
            ],
          ),
        ),
      ),
    );
  }
}
