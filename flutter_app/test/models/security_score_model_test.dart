import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/models/security_score_model.dart';

void main() {
  group('SecurityScoreModel Tests', () {
    test('fromJson parses score and factors correctly', () {
      final json = {
        'score': 85,
        'level': 'ALTO',
        'levelDescription': 'Nivel de confianza alto',
        'factors': [
          {
            'name': 'Identidad Verificada',
            'description': 'Validación biométrica y documental completada',
            'contribution': 30,
            'status': 'POSITIVE',
          },
          {
            'name': 'Dispositivos de Confianza',
            'description': 'Dispositivos vinculados y verificados',
            'contribution': 20,
            'status': 'POSITIVE',
          },
        ],
      };

      final model = SecurityScoreModel.fromJson(json);

      expect(model.score, 85);
      expect(model.level, 'ALTO');
      expect(model.levelDescription, 'Nivel de confianza alto');
      expect(model.factors.length, 2);
      expect(model.factors[0].name, 'Identidad Verificada');
      expect(model.factors[0].contribution, 30);
      expect(model.factors[0].status, 'POSITIVE');
    });
  });
}
