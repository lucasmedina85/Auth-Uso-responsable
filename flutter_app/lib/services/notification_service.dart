import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  StreamController<String>? _mockStreamController;

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
        macOS: initializationSettingsDarwin);
        
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Request permission explicitly on Android 13+
    await Permission.notification.request();

    _connectWebSocket();
  }

  void _connectWebSocket() {
    if (!kDebugMode) {
      log('WebSocket en modo producción desactivado o a la espera de endpoint seguro del backend.');
      return;
    }
    log('[ADVERTENCIA DE SEGURIDAD] Canal de notificaciones WebSocket en MODO SIMULADO / MOCK en memoria activo.');
    _mockStreamController = StreamController<String>.broadcast();
    _mockStreamController!.stream.listen((message) {
      try {
        final data = jsonDecode(message);
        if (data['type'] == 'SECURITY_ALERT') {
          showNotification(data['title'], data['body']);
        }
      } catch (e) {
        log('Error procesando mensaje WebSocket mock: $e');
      }
    });
  }

  // Helper method to simulate backend pushing an event to us
  void simulateBackendPush() {
    if (!kDebugMode) return;
    _mockStreamController?.add(jsonEncode({
      'type': 'SECURITY_ALERT',
      'title': 'Alerta de Seguridad (CU-0040) [SIMULADO]',
      'body': 'Hemos detectado un intento de inicio de sesión inusual.',
    }));
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'security_alerts_channel', 'Alertas de Seguridad',
            channelDescription: 'Canal crítico para notificaciones de seguridad y bloqueos',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await flutterLocalNotificationsPlugin.show(
        DateTime.now().millisecondsSinceEpoch ~/ 1000, 
        title, 
        body, 
        platformChannelSpecifics,
        payload: 'item x');
  }
}
