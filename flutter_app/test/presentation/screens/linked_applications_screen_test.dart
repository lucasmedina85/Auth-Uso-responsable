import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/presentation/screens/linked_applications_screen.dart';
import 'package:authenticator_juego_responsable/logic/database_log_service.dart';
import 'package:authenticator_juego_responsable/services/linked_apps_api_service.dart';

class FakeLinkedAppsService implements LinkedAppsService {
  final List<Map<String, dynamic>> apps;
  FakeLinkedAppsService(this.apps);

  @override
  Future<List<Map<String, dynamic>>> getLinkedApps() async => apps;

  @override
  Future<void> unlinkApp(String id) async {
    apps.removeWhere((a) => a['id'] == id);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLinkedAppsApiService implements LinkedAppsApiService {
  final List<Map<String, dynamic>> oauthApps;
  final bool shouldThrow;
  final Map<String, dynamic>? exportPayload;

  FakeLinkedAppsApiService({
    this.oauthApps = const [],
    this.shouldThrow = false,
    this.exportPayload,
  });

  @override
  Future<List<Map<String, dynamic>>> getLinkedApplications() async {
    if (shouldThrow) throw Exception('Fallo de conexión simulado');
    return oauthApps;
  }

  @override
  Future<bool> unlinkApplication(String clientId) async => true;

  @override
  Future<Map<String, dynamic>> exportLinkedApplicationsLog({
    String? reauthToken,
    String? startDate,
    String? endDate,
  }) async {
    return exportPayload ?? {
      'integrityHashSha256': 'sha256-test-hash-abcdef1234567890',
      'signature': 'signature-rsa-test-base64',
      'signingAlgorithm': 'SHA256withRSA',
      'payload': {
        'userPseudonym': 'pseudo-user-1234',
        'generatedAt': '2026-10-13T19:30:00',
        'totalRecords': 1,
      }
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('LinkedApplicationsScreen displays empty state when no apps exist', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LinkedApplicationsScreen(
          localService: FakeLinkedAppsService([]),
          apiService: FakeLinkedAppsApiService(oauthApps: []),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('No hay aplicaciones vinculadas.'), findsOneWidget);
  });

  testWidgets('LinkedApplicationsScreen displays combined list with TOTP and OAuth apps', (tester) async {
    final localApps = [
      {
        'id': 'totp-1',
        'name': 'Google Authenticator Demo',
        'addedAt': '2026-10-10 14:00',
        'secretSeed': 'SECRET_SEED_DO_NOT_EXPOSE',
      }
    ];

    final oauthApps = [
      {
        'clientId': 'casino-royal',
        'appName': 'Casino Royal Online',
        'linkedAt': '2026-10-11 15:30',
        'lastUsedAt': '2026-10-13 18:00',
        'tokenStatus': 'VIGENTE',
        'scopes': 'openid profile age_verification',
      }
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: LinkedApplicationsScreen(
          localService: FakeLinkedAppsService(localApps),
          apiService: FakeLinkedAppsApiService(oauthApps: oauthApps),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify both items rendered
    expect(find.text('Google Authenticator Demo'), findsOneWidget);
    expect(find.text('Casino Royal Online'), findsOneWidget);

    // Verify type badges
    expect(find.text('Código TOTP'), findsOneWidget);
    expect(find.text('Plataforma OAuth'), findsOneWidget);

    // Verify OAuth status chip and scopes
    expect(find.text('VIGENTE'), findsOneWidget);
    expect(find.textContaining('age_verification'), findsOneWidget);

    // Verify secretSeed is NEVER rendered
    expect(find.textContaining('SECRET_SEED_DO_NOT_EXPOSE'), findsNothing);
  });

  testWidgets('LinkedApplicationsScreen displays error banner on server failure but keeps local TOTP apps', (tester) async {
    final localApps = [
      {
        'id': 'totp-local-1',
        'name': 'Local Backup Token',
        'addedAt': '2026-10-01 10:00',
        'secretSeed': 'SECRET123',
      }
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: LinkedApplicationsScreen(
          localService: FakeLinkedAppsService(localApps),
          apiService: FakeLinkedAppsApiService(shouldThrow: true),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Banner of server error
    expect(find.textContaining('No se pudo conectar con el servidor'), findsOneWidget);

    // Local app still visible
    expect(find.text('Local Backup Token'), findsOneWidget);
    expect(find.text('Código TOTP'), findsOneWidget);
  });
}
