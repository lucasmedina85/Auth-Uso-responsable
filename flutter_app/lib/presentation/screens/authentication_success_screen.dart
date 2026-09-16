import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../widgets/buttons.dart';
import '../widgets/totp_components.dart';
import '../../logic/security_data_service.dart';

class AuthenticationSuccessScreen extends StatefulWidget {
  const AuthenticationSuccessScreen({super.key});

  @override
  State<AuthenticationSuccessScreen> createState() => _AuthenticationSuccessScreenState();
}

class _AuthenticationSuccessScreenState extends State<AuthenticationSuccessScreen> {
  String _locationInfo = 'Obteniendo ubicación...';
  bool _locationError = false;
  final SecurityDataService _securityDataService = SecurityDataService();

  @override
  void initState() {
    super.initState();
    _fetchLocation();
    _saveConnectionTime();
  }

  Future<void> _saveConnectionTime() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_connection_time', DateTime.now().toIso8601String());
  }

  Future<void> _fetchLocation() async {
    bool serviceEnabled;
    LocationPermission permission;
    String resolvedLocation = '';

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationInfo = 'Los servicios de ubicación están deshabilitados.';
          _locationError = true;
        });
        return;
      }

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationInfo = 'Permiso de ubicación denegado (CU-0020).';
            _locationError = true;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _locationInfo = 'Permisos denegados permanentemente.';
          _locationError = true;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        resolvedLocation = '${place.street}, ${place.locality}, ${place.country}';
      } else {
        resolvedLocation = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
      }
      
      setState(() {
        _locationInfo = resolvedLocation;
        _locationError = false;
      });

      _registerRealDevice(resolvedLocation);
    } catch (e) {
      setState(() {
        _locationInfo = 'No se pudo obtener la ubicación: $e';
        _locationError = true;
      });
    }
  }

  Future<void> _registerRealDevice(String location) async {
    DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
    String deviceName = 'Dispositivo Desconocido';
    String osName = 'SO Desconocido';
    String type = kIsWeb ? 'web' : 'mobile';

    try {
      if (kIsWeb) {
        WebBrowserInfo webInfo = await deviceInfo.webBrowserInfo;
        deviceName = webInfo.browserName.name;
        osName = webInfo.platform ?? 'Web';
      } else {
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        deviceName = androidInfo.model;
        osName = 'Android ${androidInfo.version.release}';
      }
    } catch (_) {}

    _securityDataService.updateRealDeviceActivity(
      deviceName: deviceName,
      osName: osName,
      location: location,
      type: type,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: DesignTokens.spacing24,
            vertical: DesignTokens.spacing40,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Success Header
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColorsLight.success.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.shield_outlined, // Shield icon as requested
                      size: 48,
                      color: AppColorsLight.success,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              Text(
                'Identidad verificada',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing8),
              
              Text(
                'Tu identidad fue validada correctamente.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              // Location Info Container (CU-0020)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _locationError ? theme.colorScheme.errorContainer : theme.colorScheme.primaryContainer.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(DesignTokens.radiusMedium),
                  border: Border.all(
                    color: _locationError ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on, 
                      color: _locationError ? theme.colorScheme.error : theme.colorScheme.primary
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lugar de conexión verificado',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _locationError ? theme.colorScheme.error : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _locationInfo,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _locationError ? theme.colorScheme.onErrorContainer : theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              // Authenticator Section
              Text(
                'Authenticator',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing8),
              
              Text(
                'Generá códigos temporales para acceder de forma segura a tus aplicaciones autorizadas.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              
              const SizedBox(height: DesignTokens.spacing24),
              
              // Demo Application Card
              ApplicationCard(
                appName: 'Mi Autenticador',
                deviceName: 'Este dispositivo',
                applicationId: 'demo_app',
                onCopy: () {
                  // Handled internally by ApplicationCard
                },
                onMenuTap: () {},
              ),
              
              const SizedBox(height: DesignTokens.spacing32),
              
              // Add Application Button
              PrimaryButton(
                text: '+ Agregar aplicación',
                onPressed: () {
                  Navigator.pushNamed(context, '/add_application');
                },
              ),
              
              const SizedBox(height: DesignTokens.spacing16),
              
              // Skip / Go to Dashboard
              SecondaryButton(
                text: 'Ir al Inicio',
                onPressed: () {
                  // Navigate to user dashboard, clear stack
                  Navigator.pushNamedAndRemoveUntil(context, '/dashboard', (route) => false);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
