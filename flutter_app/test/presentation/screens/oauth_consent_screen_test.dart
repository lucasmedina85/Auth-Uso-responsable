import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/presentation/screens/oauth_consent_screen.dart';

void main() {
  testWidgets('OauthConsentScreen displays loading state initially during anti-phishing validation', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OauthConsentScreen(
          clientId: 'sandbox-client',
          redirectUri: 'https://sandbox.tercero.com/callback',
          state: 'test-state-123',
          codeChallenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
          scope: 'openid',
          clientInfoFetcher: (c, r) => Completer<Map<String, dynamic>>().future,
        ),
      ),
    );

    // Initial frame displays verification message
    expect(find.text('Verificando legitimidad de la plataforma...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('OauthConsentScreen displays anti-phishing warning when client verification fails', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OauthConsentScreen(
          clientId: 'fake-unregistered-client',
          redirectUri: 'https://evil-phishing-site.com/steal',
          state: 'test-state-phishing',
          codeChallenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
          scope: 'openid',
          clientInfoFetcher: (c, r) async => throw Exception('Cliente no registrado o redirect_uri no coincide'),
        ),
      ),
    );

    // Pump to settle the failed future
    await tester.pumpAndSettle();

    // Verify anti-phishing security screen is shown
    expect(find.text('Solicitud no verificada'), findsOneWidget);
    expect(find.textContaining('Por protección anti-phishing'), findsOneWidget);
    expect(find.text('Cerrar y Volver'), findsOneWidget);
    // Consent buttons MUST NOT be rendered
    expect(find.text('Autorizar y Continuar'), findsNothing);
  });

  testWidgets('OauthConsentScreen displays verified client name and consent UI when valid', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OauthConsentScreen(
          clientId: 'casino-central',
          redirectUri: 'https://casino-central.com/auth/callback',
          state: 'test-state-valid',
          codeChallenge: 'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
          scope: 'openid age_verification',
          clientInfoFetcher: (c, r) async => {
            'clientId': 'casino-central',
            'clientName': 'Casino Central Online',
            'redirectUri': 'https://casino-central.com/auth/callback',
            'verified': true,
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('¿Autorizás a Casino Central Online?'), findsOneWidget);
    expect(find.text('Mayor de edad verificado (+18 años)'), findsOneWidget);
    expect(find.textContaining('Privacidad protegida: NO se compartirá tu nombre'), findsOneWidget);
    expect(find.text('Autorizar y Continuar'), findsOneWidget);
    expect(find.text('Rechazar'), findsOneWidget);
  });
}
