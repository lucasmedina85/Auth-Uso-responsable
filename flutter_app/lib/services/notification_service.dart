import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'dart:convert';
import 'dart:developer';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  
  WebSocketChannel? _channel;

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
    try {
      // Usamos wss://echo.websocket.events temporalmente para mock o se puede cambiar a tu WS backend local.
      _channel = WebSocketChannel.connect(
        Uri.parse('wss://echo.websocket.events'),
      );
      
      _channel!.stream.listen((message) {
        // En producción el backend mandará un JSON con la alerta
        // Para simular, cada mensaje que el WS eco envíe, mostramos notificación si cumple un formato.
        try {
          final data = jsonDecode(message);
          if (data['type'] == 'SECURITY_ALERT') {
             showNotification(data['title'], data['body']);
          }
        } catch (e) {
          // Si no es JSON ignora
        }
      },
      onDone: () {
         // Auto-reconnect
         Future.delayed(const Duration(seconds: 5), _connectWebSocket);
      },
      onError: (e) {
         log('WebSocket Error: $e');
      });
      
    } catch (e) {
       log('Error iniciando WebSocket: $e');
    }
  }

  // Helper method to simulate backend pushing an event to us
  void simulateBackendPush() {
    _channel?.sink.add(jsonEncode({
      'type': 'SECURITY_ALERT',
      'title': 'Alerta de Seguridad (CU-0040)',
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
