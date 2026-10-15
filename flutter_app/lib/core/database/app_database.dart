import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../security/local_crypto_helper.dart';

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  factory AppDatabase() => _instance;
  AppDatabase._internal();

  static const String demoUserId = 'usr-demo-001';
  static const String demoEmail = 'demo@sip.local';
  static const String demoPassword = 'Demo12345!';

  Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(docsDir.path, 'sip_local.db');

    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
        await _seedDemoData(db);
      },
    );
  }

  Future<void> _createTables(Database db) async {
    // 1. Usuarios locales
    await db.execute('''
      CREATE TABLE local_users (
        id TEXT PRIMARY KEY,
        email TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        salt TEXT NOT NULL,
        name TEXT NOT NULL,
        status TEXT NOT NULL,
        failed_attempts INTEGER NOT NULL DEFAULT 0,
        locked_until TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Dispositivos confiables
    await db.execute('''
      CREATE TABLE local_devices (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        device_id TEXT NOT NULL,
        device_name TEXT NOT NULL,
        manufacturer TEXT NOT NULL,
        os_version TEXT NOT NULL,
        device_type TEXT NOT NULL,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        last_seen_at TEXT NOT NULL
      )
    ''');

    // 3. Actividad reciente / Timeline
    await db.execute('''
      CREATE TABLE local_activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        type TEXT NOT NULL,
        action TEXT NOT NULL,
        description TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        device_id TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        severity TEXT NOT NULL
      )
    ''');

    // 4. Bitácora con hash encadenado (CU-0050)
    await db.execute('''
      CREATE TABLE local_audit_chain (
        chain_index INTEGER PRIMARY KEY,
        timestamp TEXT NOT NULL,
        event_type TEXT NOT NULL,
        payload TEXT NOT NULL,
        prev_hash TEXT NOT NULL,
        hash TEXT NOT NULL
      )
    ''');

    // 5. Aplicaciones vinculadas (TOTP y OAuth)
    await db.execute('''
      CREATE TABLE local_linked_apps (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        client_id TEXT,
        type TEXT NOT NULL,
        added_at TEXT NOT NULL,
        secret_seed TEXT,
        scopes TEXT,
        status TEXT NOT NULL
      )
    ''');

    // 6. Tokens OAuth locales simulados
    await db.execute('''
      CREATE TABLE local_oauth_tokens (
        id TEXT PRIMARY KEY,
        client_id TEXT NOT NULL,
        user_id TEXT NOT NULL,
        token TEXT NOT NULL,
        token_type TEXT NOT NULL,
        issued_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        revoked INTEGER NOT NULL DEFAULT 0,
        scopes TEXT NOT NULL
      )
    ''');
  }

  Future<void> _seedDemoData(Database db) async {
    final now = DateTime.now();
    final monthAgo = now.subtract(const Duration(days: 30));

    // Usuario demo precargado
    final salt = LocalCryptoHelper.generateSalt();
    final hash = LocalCryptoHelper.hashPassword(demoPassword, salt);

    await db.insert('local_users', {
      'id': demoUserId,
      'email': demoEmail,
      'password_hash': hash,
      'salt': salt,
      'name': 'Usuario Demo SIP',
      'status': 'LOCALLY_VERIFIED',
      'failed_attempts': 0,
      'locked_until': null,
      'created_at': monthAgo.toIso8601String(),
    });

    // Dispositivo demo primario (confiable)
    await db.insert('local_devices', {
      'id': 'dev-demo-001',
      'user_id': demoUserId,
      'device_id': 'demo-primary-device',
      'device_name': 'Samsung Galaxy (Este dispositivo)',
      'manufacturer': 'Samsung',
      'os_version': 'Android 14',
      'device_type': 'MOBILE',
      'status': 'TRUSTED',
      'created_at': monthAgo.toIso8601String(),
      'last_seen_at': now.toIso8601String(),
    });

    // Actividades precargadas
    final activities = [
      {
        'user_id': demoUserId,
        'type': 'VERIFICATION',
        'action': 'Prueba Biométrica Facial',
        'description': 'Validación facial 1:1 exitosa con score 96%',
        'ip_address': '190.191.***.***',
        'device_id': 'demo-primary-device',
        'timestamp': monthAgo.add(const Duration(hours: 1)).toIso8601String(),
        'severity': 'INFO',
      },
      {
        'user_id': demoUserId,
        'type': 'DEVICE',
        'action': 'Dispositivo Vinculado',
        'description': 'Samsung Galaxy registrado como dispositivo confiable',
        'ip_address': '190.191.***.***',
        'device_id': 'demo-primary-device',
        'timestamp': monthAgo.add(const Duration(hours: 2)).toIso8601String(),
        'severity': 'INFO',
      },
      {
        'user_id': demoUserId,
        'type': 'LOGIN',
        'action': 'Inicio de Sesión Local',
        'description': 'Autenticación exitosa con credenciales locales',
        'ip_address': '190.191.***.***',
        'device_id': 'demo-primary-device',
        'timestamp': now.subtract(const Duration(hours: 3)).toIso8601String(),
        'severity': 'INFO',
      },
    ];

    for (final act in activities) {
      await db.insert('local_activity_logs', act);
    }

    // Bloque génesis de bitácora encadenada (CU-0050)
    const genesisPrevHash = '0000000000000000000000000000000000000000000000000000000000000000';
    final genesisPayload = jsonEncode({
      'description': 'Bloque génesis de bitácora local SIP',
      'origin': 'LOCAL_DEMO',
      'initialized_at': monthAgo.toIso8601String(),
    });
    final genesisHash = LocalCryptoHelper.sha256Hex(
      '0:${monthAgo.toIso8601String()}:GENESIS:$genesisPayload:$genesisPrevHash',
    );

    await db.insert('local_audit_chain', {
      'chain_index': 0,
      'timestamp': monthAgo.toIso8601String(),
      'event_type': 'GENESIS',
      'payload': genesisPayload,
      'prev_hash': genesisPrevHash,
      'hash': genesisHash,
    });

    // Aplicaciones vinculadas demo: 1 TOTP y 1 OAuth
    await db.insert('local_linked_apps', {
      'id': 'app-totp-001',
      'user_id': demoUserId,
      'name': 'Google Authenticator',
      'client_id': null,
      'type': 'TOTP',
      'added_at': monthAgo.add(const Duration(days: 5)).toIso8601String(),
      'secret_seed': 'JBSWY3DPEHPK3PXP',
      'scopes': 'totp:generate',
      'status': 'ACTIVE',
    });

    await db.insert('local_linked_apps', {
      'id': 'app-oauth-001',
      'user_id': demoUserId,
      'name': 'Plataforma de Apuestas Responsables S.A.',
      'client_id': 'client_casino_sip_01',
      'type': 'OAUTH',
      'added_at': monthAgo.add(const Duration(days: 12)).toIso8601String(),
      'secret_seed': null,
      'scopes': 'read:profile,verify:age',
      'status': 'ACTIVE',
    });
  }

  // ==================== USUARIOS ====================

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final db = await database;
    final res = await db.query(
      'local_users',
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return Map<String, dynamic>.from(res.first);
  }

  Future<Map<String, dynamic>?> getUserById(String id) async {
    final db = await database;
    final res = await db.query(
      'local_users',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (res.isEmpty) return null;
    return Map<String, dynamic>.from(res.first);
  }

  Future<void> createUser({
    required String email,
    required String password,
    required String name,
    String status = 'REGISTERED',
  }) async {
    final db = await database;
    final id = 'usr-${DateTime.now().millisecondsSinceEpoch}';
    final salt = LocalCryptoHelper.generateSalt();
    final hash = LocalCryptoHelper.hashPassword(password, salt);

    await db.insert('local_users', {
      'id': id,
      'email': email.toLowerCase().trim(),
      'password_hash': hash,
      'salt': salt,
      'name': name.trim(),
      'status': status,
      'failed_attempts': 0,
      'locked_until': null,
      'created_at': DateTime.now().toIso8601String(),
    });

    await addAuditEvent(
      'USER_REGISTERED',
      {'userId': id, 'email': email.toLowerCase().trim(), 'status': status},
    );
  }

  Future<void> updateUserStatus(String userId, String newStatus) async {
    final db = await database;
    await db.update(
      'local_users',
      {'status': newStatus},
      where: 'id = ?',
      whereArgs: [userId],
    );
    await addAuditEvent('USER_STATUS_UPDATED', {'userId': userId, 'newStatus': newStatus});
  }

  Future<int> incrementFailedAttempts(String email) async {
    final db = await database;
    final user = await getUserByEmail(email);
    if (user == null) return 0;

    final currentAttempts = (user['failed_attempts'] as int? ?? 0) + 1;
    await db.update(
      'local_users',
      {'failed_attempts': currentAttempts},
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    return currentAttempts;
  }

  Future<void> resetFailedAttempts(String email) async {
    final db = await database;
    await db.update(
      'local_users',
      {'failed_attempts': 0, 'locked_until': null},
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
  }

  Future<void> lockUserUntil(String email, DateTime until) async {
    final db = await database;
    await db.update(
      'local_users',
      {
        'locked_until': until.toIso8601String(),
      },
      where: 'LOWER(email) = ?',
      whereArgs: [email.toLowerCase().trim()],
    );
    await addAuditEvent('USER_LOCKED', {
      'email': email.toLowerCase().trim(),
      'lockedUntil': until.toIso8601String(),
    });
  }

  // ==================== DISPOSITIVOS ====================

  Future<List<Map<String, dynamic>>> getDevices({String? userId}) async {
    final db = await database;
    final targetUser = userId ?? demoUserId;
    final res = await db.query(
      'local_devices',
      where: 'user_id = ?',
      whereArgs: [targetUser],
      orderBy: 'created_at DESC',
    );
    return res.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<Map<String, dynamic>> registerDevice(Map<String, dynamic> device) async {
    final db = await database;
    final existing = await db.query(
      'local_devices',
      where: 'device_id = ? AND user_id = ?',
      whereArgs: [device['deviceId'], device['userId'] ?? demoUserId],
    );

    if (existing.isNotEmpty) {
      final updated = Map<String, dynamic>.from(existing.first);
      updated['last_seen_at'] = DateTime.now().toIso8601String();
      await db.update(
        'local_devices',
        {'last_seen_at': updated['last_seen_at']},
        where: 'id = ?',
        whereArgs: [updated['id']],
      );
      return updated;
    }

    final id = 'dev-${DateTime.now().millisecondsSinceEpoch}';
    final allDevices = await getDevices(userId: device['userId'] ?? demoUserId);
    // El primer dispositivo es TRUSTED, los subsiguientes quedan PENDING
    final status = allDevices.isEmpty ? 'TRUSTED' : 'PENDING';

    final row = {
      'id': id,
      'user_id': device['userId'] ?? demoUserId,
      'device_id': device['deviceId'] ?? 'unknown-dev',
      'device_name': device['deviceName'] ?? 'Dispositivo móvil',
      'manufacturer': device['manufacturer'] ?? 'Desconocido',
      'os_version': device['osVersion'] ?? 'Android',
      'device_type': device['deviceType'] ?? 'MOBILE',
      'status': status,
      'created_at': DateTime.now().toIso8601String(),
      'last_seen_at': DateTime.now().toIso8601String(),
    };

    await db.insert('local_devices', row);
    await addAuditEvent('DEVICE_REGISTERED', {'deviceId': id, 'status': status});
    return row;
  }

  Future<void> updateDeviceStatus(String deviceId, String status) async {
    final db = await database;
    await db.update(
      'local_devices',
      {'status': status},
      where: 'device_id = ? OR id = ?',
      whereArgs: [deviceId, deviceId],
    );
    await addAuditEvent('DEVICE_STATUS_CHANGED', {'deviceId': deviceId, 'status': status});
  }

  // ==================== ACTIVIDAD RECIENTE ====================

  Future<void> logActivity({
    String? userId,
    required String type,
    required String action,
    required String description,
    String ipAddress = '190.191.***.***',
    String deviceId = 'demo-device',
    String severity = 'INFO',
  }) async {
    final db = await database;
    final row = {
      'user_id': userId ?? demoUserId,
      'type': type,
      'action': action,
      'description': description,
      'ip_address': ipAddress,
      'device_id': deviceId,
      'timestamp': DateTime.now().toIso8601String(),
      'severity': severity,
    };
    await db.insert('local_activity_logs', row);
  }

  Future<List<Map<String, dynamic>>> getActivityLogs({
    String? userId,
    String? type,
    int page = 0,
    int size = 20,
  }) async {
    final db = await database;
    final targetUser = userId ?? demoUserId;
    
    String whereClause = 'user_id = ?';
    List<dynamic> whereArgs = [targetUser];

    if (type != null && type.isNotEmpty && type != 'ALL') {
      whereClause += ' AND type = ?';
      whereArgs.add(type);
    }

    final res = await db.query(
      'local_activity_logs',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'timestamp DESC',
      limit: size,
      offset: page * size,
    );

    return res.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ==================== BITÁCORA CON HASH ENCADENADO (CU-0050) ====================

  Future<void> addAuditEvent(String eventType, Map<String, dynamic> payload) async {
    final db = await database;
    final lastRow = await db.query(
      'local_audit_chain',
      orderBy: 'chain_index DESC',
      limit: 1,
    );

    int nextIndex = 0;
    String prevHash = '0000000000000000000000000000000000000000000000000000000000000000';

    if (lastRow.isNotEmpty) {
      nextIndex = (lastRow.first['chain_index'] as int) + 1;
      prevHash = lastRow.first['hash'] as String;
    }

    final timestamp = DateTime.now().toIso8601String();
    final payloadJson = jsonEncode(payload);
    final hash = LocalCryptoHelper.sha256Hex(
      '$nextIndex:$timestamp:$eventType:$payloadJson:$prevHash',
    );

    await db.insert('local_audit_chain', {
      'chain_index': nextIndex,
      'timestamp': timestamp,
      'event_type': eventType,
      'payload': payloadJson,
      'prev_hash': prevHash,
      'hash': hash,
    });
  }

  Future<List<Map<String, dynamic>>> getAuditChain() async {
    final db = await database;
    final res = await db.query('local_audit_chain', orderBy: 'chain_index ASC');
    return res.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  /// Verifica la integridad de la cadena criptográfica completa (CU-0050)
  Future<bool> verifyChainIntegrity() async {
    final chain = await getAuditChain();
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
          return false; // Eslabón roto
        }
      }

      final expectedHash = LocalCryptoHelper.sha256Hex(
        '$index:$timestamp:$eventType:$payload:$prevHash',
      );

      if (hash != expectedHash) {
        return false; // Contenido alterado
      }
    }
    return true;
  }

  // ==================== APLICACIONES VINCULADAS ====================

  Future<List<Map<String, dynamic>>> getLinkedApps({String? userId}) async {
    final db = await database;
    final targetUser = userId ?? demoUserId;
    final res = await db.query(
      'local_linked_apps',
      where: 'user_id = ? AND status != ?',
      whereArgs: [targetUser, 'REVOKED'],
      orderBy: 'added_at DESC',
    );
    return res.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  Future<void> addLinkedApp({
    String? userId,
    required String name,
    String? clientId,
    required String type,
    String? secretSeed,
    String? scopes,
  }) async {
    final db = await database;
    final id = 'app-${DateTime.now().millisecondsSinceEpoch}';
    final now = DateTime.now().toIso8601String();

    await db.insert('local_linked_apps', {
      'id': id,
      'user_id': userId ?? demoUserId,
      'name': name,
      'client_id': clientId,
      'type': type,
      'added_at': now,
      'secret_seed': secretSeed,
      'scopes': scopes,
      'status': 'ACTIVE',
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await addAuditEvent('APP_LINKED', {
      'appId': id,
      'name': name,
      'type': type,
    });
  }

  Future<void> revokeLinkedApp(String id) async {
    final db = await database;
    await db.update(
      'local_linked_apps',
      {'status': 'REVOKED'},
      where: 'id = ?',
      whereArgs: [id],
    );
    await addAuditEvent('APP_REVOKED', {'appId': id});
  }

  // ==================== REINICIAR BASE PARA PRUEBAS ====================

  Future<void> resetForDemo() async {
    final db = await database;
    await db.delete('local_users');
    await db.delete('local_devices');
    await db.delete('local_activity_logs');
    await db.delete('local_audit_chain');
    await db.delete('local_linked_apps');
    await db.delete('local_oauth_tokens');
    await _seedDemoData(db);
  }
}
