import 'package:flutter/material.dart';

enum SecurityLevel { low, medium, high }
enum EventStatus { success, warning, error, blocked }

class SecurityLog {
  final String id;
  final String date;
  final String time;
  final String eventType;
  final EventStatus status;
  final String result;
  final String device;
  final String os;
  final String ip;
  final String location;
  final String authMethod;
  final SecurityLevel securityLevel;
  final List<String> evidenceImages;

  SecurityLog({
    required this.id,
    required this.date,
    required this.time,
    required this.eventType,
    required this.status,
    required this.result,
    required this.device,
    required this.os,
    required this.ip,
    required this.location,
    required this.authMethod,
    required this.securityLevel,
    this.evidenceImages = const [],
  });
}

class TrustedDevice {
  final String id;
  final String name;
  final String type; // 'mobile', 'web', 'external'
  final String os;
  final String associatedApp;
  final String status;
  final String lastConnectionDate;
  final String lastConnectionTime;
  final String location;

  TrustedDevice({
    required this.id,
    required this.name,
    required this.type,
    required this.os,
    required this.associatedApp,
    required this.status,
    required this.lastConnectionDate,
    required this.lastConnectionTime,
    required this.location,
  });
}

class SecurityActivity {
  final String date;
  final String time;
  final String ip;
  final String device;
  final String location;
  final String event;
  final EventStatus status;

  SecurityActivity({
    required this.date,
    required this.time,
    required this.ip,
    required this.device,
    required this.location,
    required this.event,
    required this.status,
  });
}

class SecurityDataService {
  static final SecurityDataService _instance = SecurityDataService._internal();
  factory SecurityDataService() => _instance;
  
  late final List<TrustedDevice> _devices;
  final Map<String, List<SecurityActivity>> _activitiesMap = {};
  
  String? dniFrontPath;
  String? dniBackPath;
  String? livenessVideoPath;

  SecurityDataService._internal() {
    _devices = getMockDevices();
  }

  List<SecurityLog> getMockLogs() {
    return [
      SecurityLog(
        id: 'AUTH-902341A',
        date: '01/09/2026',
        time: '14:32:08',
        eventType: 'Autenticación exitosa',
        status: EventStatus.success,
        result: 'Verificado',
        device: 'Samsung Galaxy S24',
        os: 'Android 14',
        ip: '190.24.123.45',
        location: 'Buenos Aires, Argentina',
        authMethod: 'Reconocimiento facial',
        securityLevel: SecurityLevel.high,
      ),
      SecurityLog(
        id: 'AUTH-902340B',
        date: '01/09/2026',
        time: '14:30:12',
        eventType: 'Validación DNI',
        status: EventStatus.success,
        result: 'Verificado',
        device: 'Samsung Galaxy S24',
        os: 'Android 14',
        ip: '190.24.123.45',
        location: 'Buenos Aires, Argentina',
        authMethod: 'OCR',
        securityLevel: SecurityLevel.high,
        evidenceImages: [
          'assets/images/dni_front_mock.png',
          'assets/images/dni_back_mock.png',
        ],
      ),
      SecurityLog(
        id: 'AUTH-801231C',
        date: '31/08/2026',
        time: '09:15:00',
        eventType: 'Intento bloqueado',
        status: EventStatus.blocked,
        result: 'Rechazado',
        device: 'Unknown Browser',
        os: 'Windows 11',
        ip: '45.22.19.102',
        location: 'Moscú, Rusia',
        authMethod: 'Contraseña',
        securityLevel: SecurityLevel.low,
      ),
      SecurityLog(
        id: 'AUTH-801230D',
        date: '30/08/2026',
        time: '18:45:22',
        eventType: 'Cambio de contraseña',
        status: EventStatus.success,
        result: 'Completado',
        device: 'MacBook Pro',
        os: 'macOS Sonoma',
        ip: '190.24.123.45',
        location: 'Buenos Aires, Argentina',
        authMethod: 'Biometría',
        securityLevel: SecurityLevel.high,
      ),
      SecurityLog(
        id: 'AUTH-801229E',
        date: '28/08/2026',
        time: '11:20:05',
        eventType: 'Dispositivo autorizado',
        status: EventStatus.warning,
        result: 'Pendiente confirmación',
        device: 'iPhone 15',
        os: 'iOS 17',
        ip: '181.12.33.90',
        location: 'Córdoba, Argentina',
        authMethod: 'TOTP',
        securityLevel: SecurityLevel.medium,
      ),
    ];
  }

  List<TrustedDevice> getMockDevices() {
    return [
      TrustedDevice(
        id: 'DEV-01',
        name: 'Samsung Galaxy S24',
        type: 'mobile',
        os: 'Android 14',
        associatedApp: 'Authenticator',
        status: 'Dispositivo confiable',
        lastConnectionDate: '01/09/2026',
        lastConnectionTime: '14:32',
        location: 'Buenos Aires, Argentina',
      ),
      TrustedDevice(
        id: 'DEV-02',
        name: 'Aplicación de apuestas',
        type: 'external',
        os: 'N/A',
        associatedApp: 'N/A',
        status: 'Autorizada',
        lastConnectionDate: '01/09/2026',
        lastConnectionTime: '14:32',
        location: 'Buenos Aires, Argentina',
      ),
      TrustedDevice(
        id: 'DEV-03',
        name: 'MacBook Pro',
        type: 'web',
        os: 'macOS',
        associatedApp: 'Panel de Administración',
        status: 'Dispositivo confiable',
        lastConnectionDate: '30/08/2026',
        lastConnectionTime: '18:45',
        location: 'Buenos Aires, Argentina',
      ),
    ];
  }

  List<TrustedDevice> getDevices() {
    return List.unmodifiable(_devices);
  }

  TrustedDevice getLatestDevice() {
    return _devices.isNotEmpty ? _devices.first : getMockDevices().first;
  }

  void addDevice(TrustedDevice device) {
    _devices.insert(0, device);
    // Add default initial registration activity
    final initialActivity = SecurityActivity(
      date: 'Hoy',
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      ip: '190.24.123.45',
      device: device.name,
      location: device.location,
      event: 'Aplicación autorizada y vinculada',
      status: EventStatus.success,
    );
    if (_activitiesMap.containsKey(device.id)) {
      _activitiesMap[device.id]!.insert(0, initialActivity);
    } else {
      _activitiesMap[device.id] = [initialActivity, ...getMockActivity(device.id)];
    }
  }

  List<SecurityActivity> getMockActivity(String deviceId) {
    if (_activitiesMap.containsKey(deviceId)) {
      return _activitiesMap[deviceId]!;
    }
    return [
      SecurityActivity(
        date: 'Hoy',
        time: '14:32',
        ip: '190.24.123.45',
        device: 'Samsung Galaxy S24',
        location: 'Buenos Aires',
        event: 'Inicio de sesión exitoso',
        status: EventStatus.success,
      ),
      SecurityActivity(
        date: 'Ayer',
        time: '19:14',
        ip: '190.24.123.45',
        device: 'Samsung Galaxy S24',
        location: 'Buenos Aires',
        event: 'Inicio de sesión',
        status: EventStatus.success,
      ),
      SecurityActivity(
        date: '30/08/2026',
        time: '11:05',
        ip: '45.22.19.102',
        device: 'Unknown',
        location: 'Moscú, Rusia',
        event: 'Intento de acceso bloqueado',
        status: EventStatus.blocked,
      ),
    ];
  }

  Future<void> exportCsvMock(BuildContext context) async {
    // Simulate delay
    await Future.delayed(const Duration(seconds: 1));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El historial fue exportado correctamente. (CSV Descargado)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
