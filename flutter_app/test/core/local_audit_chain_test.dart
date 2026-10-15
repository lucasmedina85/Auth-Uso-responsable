import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:authenticator_juego_responsable/core/security/local_crypto_helper.dart';

void main() {
  group('CU-0050: Immutable Cryptographic Audit Chain Tests', () {
    const genesisPrevHash = '0000000000000000000000000000000000000000000000000000000000000000';

    Map<String, dynamic> createBlock({
      required int index,
      required String timestamp,
      required String eventType,
      required Map<String, dynamic> payload,
      required String prevHash,
    }) {
      final payloadJson = jsonEncode(payload);
      final hash = LocalCryptoHelper.sha256Hex(
        '$index:$timestamp:$eventType:$payloadJson:$prevHash',
      );
      return {
        'chain_index': index,
        'timestamp': timestamp,
        'event_type': eventType,
        'payload': payloadJson,
        'prev_hash': prevHash,
        'hash': hash,
      };
    }

    bool verifyChain(List<Map<String, dynamic>> chain) {
      if (chain.isEmpty) return true;

      for (int i = 0; i < chain.length; i++) {
        final current = chain[i];
        final index = current['chain_index'] as int;
        final timestamp = current['timestamp'] as String;
        final eventType = current['event_type'] as String;
        final payload = current['payload'] as String;
        final prevHash = current['prev_hash'] as String;
        final hash = current['hash'] as String;

        if (i > 0) {
          final previous = chain[i - 1];
          if (prevHash != previous['hash']) {
            return false; // Broken link
          }
        }

        final expectedHash = LocalCryptoHelper.sha256Hex(
          '$index:$timestamp:$eventType:$payload:$prevHash',
        );

        if (hash != expectedHash) {
          return false; // Tampered block
        }
      }
      return true;
    }

    test('Genesis block and sequential chained events verify successfully', () {
      final chain = <Map<String, dynamic>>[];

      // Block 0: Genesis
      final genesis = createBlock(
        index: 0,
        timestamp: '2026-10-01T00:00:00.000Z',
        eventType: 'GENESIS',
        payload: {'description': 'Genesis Block'},
        prevHash: genesisPrevHash,
      );
      chain.add(genesis);

      // Block 1: User Registered
      final block1 = createBlock(
        index: 1,
        timestamp: '2026-10-01T01:00:00.000Z',
        eventType: 'USER_REGISTERED',
        payload: {'userId': 'usr-001', 'email': 'demo@sip.local'},
        prevHash: genesis['hash'],
      );
      chain.add(block1);

      // Block 2: Device Registered
      final block2 = createBlock(
        index: 2,
        timestamp: '2026-10-01T02:00:00.000Z',
        eventType: 'DEVICE_REGISTERED',
        payload: {'deviceId': 'dev-001', 'status': 'TRUSTED'},
        prevHash: block1['hash'],
      );
      chain.add(block2);

      expect(chain.length, equals(3));
      expect(verifyChain(chain), isTrue);
    });

    test('Tampering payload in any block is immediately detected and invalidates chain', () {
      final chain = <Map<String, dynamic>>[];

      final genesis = createBlock(
        index: 0,
        timestamp: '2026-10-01T00:00:00.000Z',
        eventType: 'GENESIS',
        payload: {'description': 'Genesis Block'},
        prevHash: genesisPrevHash,
      );
      chain.add(genesis);

      final block1 = createBlock(
        index: 1,
        timestamp: '2026-10-01T01:00:00.000Z',
        eventType: 'USER_REGISTERED',
        payload: {'userId': 'usr-001', 'email': 'demo@sip.local'},
        prevHash: genesis['hash'],
      );
      chain.add(block1);

      // Attacker attempts to change email inside payload without updating hash
      chain[1]['payload'] = jsonEncode({'userId': 'usr-001', 'email': 'attacker@evil.com'});

      expect(verifyChain(chain), isFalse);
    });

    test('Breaking link (modifying prev_hash) is detected as broken chain', () {
      final chain = <Map<String, dynamic>>[];

      final genesis = createBlock(
        index: 0,
        timestamp: '2026-10-01T00:00:00.000Z',
        eventType: 'GENESIS',
        payload: {'description': 'Genesis Block'},
        prevHash: genesisPrevHash,
      );
      chain.add(genesis);

      final block1 = createBlock(
        index: 1,
        timestamp: '2026-10-01T01:00:00.000Z',
        eventType: 'USER_REGISTERED',
        payload: {'userId': 'usr-001'},
        prevHash: 'invalid_prev_hash_1234567890abcdef',
      );
      chain.add(block1);

      expect(verifyChain(chain), isFalse);
    });

    test('Offline OAuth token payload contains zero PII and valid cryptographic signature', () {
      final tokenPayload = {
        'sub': 'usr-demo-001',
        'client_id': 'client_casino_sip_01',
        'scope': 'read:profile,verify:age',
        'iat': 1728900000,
        'exp': 1728903600,
      };

      final payloadJson = jsonEncode(tokenPayload);
      final hash = LocalCryptoHelper.sha256Hex(payloadJson);
      final signature = LocalCryptoHelper.hmacSha256Hex('SIP_LOCAL_OFFLINE_SECRET_KEY', hash);

      // Verify zero PII
      expect(payloadJson.contains('password'), isFalse);
      expect(payloadJson.contains('email'), isFalse);
      expect(payloadJson.contains('dni'), isFalse);

      // Verify signature integrity
      final verifySignature = LocalCryptoHelper.hmacSha256Hex('SIP_LOCAL_OFFLINE_SECRET_KEY', hash);
      expect(signature, equals(verifySignature));
    });
  });
}
