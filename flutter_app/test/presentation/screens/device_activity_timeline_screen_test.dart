import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/presentation/screens/device_activity_timeline_screen.dart';
import 'package:authenticator_juego_responsable/services/user_activity_api_service.dart';

class FakeUserActivityApiService implements UserActivityApiService {
  final List<Map<String, dynamic>> events;
  final bool hasNext;
  String? lastTypeRequested;

  FakeUserActivityApiService({
    required this.events,
    this.hasNext = false,
  });

  @override
  Future<Map<String, dynamic>> getUserActivity({
    int page = 0,
    int size = 20,
    String? type,
    String? startDate,
    String? endDate,
  }) async {
    lastTypeRequested = type;
    final filtered = (type == null || type == 'ALL')
        ? events
        : events.where((e) => e['type'] == type).toList();

    return {
      'events': filtered,
      'page': page,
      'size': size,
      'totalElements': filtered.length,
      'totalPages': 1,
      'hasNext': hasNext,
    };
  }

  @override
  Future<Map<String, dynamic>> exportUserActivity({
    String? reauthToken,
    String? startDate,
    String? endDate,
  }) async {
    return {
      'integrityHashSha256': 'sha256-activity-test-hash-12345678',
      'signature': 'signature-rsa-activity-base64',
      'signingAlgorithm': 'SHA256withRSA',
      'payload': {
        'userPseudonym': 'usr-activity-pseudo',
        'dateRange': 'INICIO a ACTUAL',
        'generatedAt': '2026-10-13T19:30:00',
        'totalRecords': events.length,
      }
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('DeviceActivityTimelineScreen displays empty state when no activities exist', (tester) async {
    final fakeService = FakeUserActivityApiService(events: []);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceActivityTimelineScreen(apiService: fakeService),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('No hay actividades registradas.'), findsOneWidget);
  });

  testWidgets('DeviceActivityTimelineScreen renders real events, masked IP, and blockchain Tx reference', (tester) async {
    final testEvents = [
      {
        'id': 'bc-1',
        'type': 'VALIDATION',
        'timestamp': '2026-10-13 18:45:00',
        'description': 'Evaluación de riesgo operacional: AUTORIZAR',
        'decision': 'AUTORIZAR',
        'result': 'AUTORIZAR',
        'maskedIp': '190.220.***.***',
        'txRef': '0xabcdef0123456789',
      },
      {
        'id': 'log-1',
        'type': 'LOGIN',
        'timestamp': '2026-10-13 17:00:00',
        'description': 'Registro de cuenta e inicio inicial',
        'result': 'SUCCESS',
      }
    ];

    final fakeService = FakeUserActivityApiService(events: testEvents);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceActivityTimelineScreen(apiService: fakeService),
      ),
    );

    await tester.pumpAndSettle();

    // Verify descriptions
    expect(find.text('Evaluación de riesgo operacional: AUTORIZAR'), findsOneWidget);
    expect(find.text('Registro de cuenta e inicio inicial'), findsOneWidget);

    // Verify IP
    expect(find.text('IP: 190.220.***.***'), findsOneWidget);

    // Verify Blockchain Tx reference
    expect(find.text('Tx Blockchain: 0xabcdef0123456789'), findsOneWidget);

    // Verify badges
    expect(find.text('AUTORIZAR'), findsOneWidget);
    expect(find.text('SUCCESS'), findsOneWidget);
  });

  testWidgets('DeviceActivityTimelineScreen filters events by type chip tap', (tester) async {
    final testEvents = [
      {
        'id': 'ev-1',
        'type': 'LOGIN',
        'timestamp': '2026-10-13 10:00:00',
        'description': 'Login exitoso',
        'result': 'SUCCESS',
      },
      {
        'id': 'ev-2',
        'type': 'VALIDATION',
        'timestamp': '2026-10-13 11:00:00',
        'description': 'Evaluación de riesgo',
        'result': 'SUCCESS',
      }
    ];

    final fakeService = FakeUserActivityApiService(events: testEvents);

    await tester.pumpWidget(
      MaterialApp(
        home: DeviceActivityTimelineScreen(apiService: fakeService),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Login exitoso'), findsOneWidget);
    expect(find.text('Evaluación de riesgo'), findsOneWidget);

    // Tap filter chip "Validaciones"
    await tester.tap(find.text('Validaciones'));
    await tester.pumpAndSettle();

    expect(fakeService.lastTypeRequested, equals('VALIDATION'));
    expect(find.text('Evaluación de riesgo'), findsOneWidget);
    expect(find.text('Login exitoso'), findsNothing);
  });
}
