import 'package:flutter/material.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import '../widgets/shared_bottom_nav_bar.dart';
import 'package:geocoding/geocoding.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/theme/app_theme.dart';
import '../../logic/security_data_service.dart';

class DeviceActivityTimelineScreen extends StatefulWidget {
  const DeviceActivityTimelineScreen({super.key});

  @override
  State<DeviceActivityTimelineScreen> createState() => _DeviceActivityTimelineScreenState();
}

class _DeviceActivityTimelineScreenState extends State<DeviceActivityTimelineScreen> {
  final SecurityDataService _dataService = SecurityDataService();
  List<SecurityActivity> _activities = [];
  TrustedDevice? _device;
  bool _isLoading = true;

  String _email = 'Usuario';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments;
    
    if (args is Map) {
      _email = args['email'] as String? ?? 'Usuario';
    }

    // Always attempt to load real context for the timeline if we navigate here
    _loadRealDeviceContext();
  }

  Future<void> _loadRealDeviceContext() async {
    // Attempt to get location
    String location = 'Ubicación desconocida';
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
          Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
          List<Placemark> placemarks = await placemarkFromCoordinates(pos.latitude, pos.longitude);
          if (placemarks.isNotEmpty) {
            location = '${placemarks[0].street}, ${placemarks[0].locality}';
          }
        }
      }
    } catch (_) {}

    // Get Device Info
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

    // Force update the singleton with real info
    _dataService.updateRealDeviceActivity(
      deviceName: deviceName,
      osName: osName,
      location: location,
      type: type,
    );

    setState(() {
      _device = _dataService.getLatestDevice();
      // Ensure we only show the real activities, stripping out old mock data for this view
      _activities = _dataService.getMockActivity(_device!.id).where((act) => act.device == deviceName).toList();
      
      // Fallback if filtering removed everything
      if (_activities.isEmpty) {
         _activities = _dataService.getMockActivity(_device!.id);
      }
      
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading || _device == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Actividad')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final device = _device!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Actividad'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Configuración de Validación',
            onPressed: () {
              Navigator.pushNamed(
                context, 
                '/validation_config',
                arguments: {'email': _email},
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Device Header
            Container(
              padding: const EdgeInsets.all(DesignTokens.spacing24),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
              child: Row(
                children: [
                  Icon(
                    device.type == 'mobile' ? Icons.smartphone : Icons.computer,
                    size: 32,
                    color: theme.primaryColor,
                  ),
                  const SizedBox(width: DesignTokens.spacing16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          device.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Sesión activa: $_email',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: DesignTokens.spacing4),
                        Text(
                          'Últimas conexiones registradas',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: DesignTokens.spacing16),
            
            // Timeline List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(DesignTokens.spacing24),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final isLast = index == _activities.length - 1;
                  return _buildTimelineItem(context, _activities[index], isLast);
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SharedBottomNavBar(
        currentIndex: 1,
        displayName: _email,
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, SecurityActivity activity, bool isLast) {
    final theme = Theme.of(context);
    
    Color dotColor = theme.primaryColor;
    if (activity.status == EventStatus.blocked || activity.status == EventStatus.error) {
      dotColor = theme.colorScheme.error;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline visual
          Column(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: theme.colorScheme.surface, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: dotColor.withOpacity(0.3),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: theme.colorScheme.outlineVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(width: DesignTokens.spacing16),
          
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: DesignTokens.spacing32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${activity.date} — ${activity.time}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing4),
                  Text(
                    activity.event,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: activity.status == EventStatus.blocked ? theme.colorScheme.error : null,
                    ),
                  ),
                  const SizedBox(height: DesignTokens.spacing8),
                  Text(
                    activity.device,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'Ubicación: ${activity.location}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    'IP: ${activity.ip}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
