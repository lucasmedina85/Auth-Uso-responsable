import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:authenticator_juego_responsable/main.dart';
import 'package:authenticator_juego_responsable/presentation/screens/verification_review_screen.dart';

void main() {
  testWidgets('App starts with AuthenticatorApp', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const AuthenticatorApp());
    await tester.pump();

    // Verify MaterialApp exists and is rendered
    expect(find.byType(MaterialApp), findsOneWidget);
  });

  testWidgets('VerificationReviewScreen renders expected guidance and reference code', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VerificationReviewScreen(
          reviewData: {
            'status': 'UNDER_REVIEW',
            'decision': 'REVISIÓN',
            'riskScore': 65,
          },
        ),
      ),
    );

    // Verify title and informative content
    expect(find.text('Validación en Revisión'), findsOneWidget);
    expect(find.text('Tu solicitud requiere una verificación complementaria por parte de nuestro equipo de seguridad.'), findsOneWidget);
    expect(find.textContaining('Plazo estimado: 24 a 48 horas'), findsOneWidget);
    expect(find.text('Código de referencia: REF-065'), findsOneWidget);
    expect(find.text('Entendido / Volver al Inicio'), findsOneWidget);
  });
}

