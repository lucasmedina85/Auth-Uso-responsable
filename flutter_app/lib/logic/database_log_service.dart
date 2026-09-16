import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

class DatabaseLogService {
  static final DatabaseLogService _instance = DatabaseLogService._internal();
  factory DatabaseLogService() => _instance;
  DatabaseLogService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final docsDirectory = await getApplicationDocumentsDirectory();
    final path = join(docsDirectory.path, 'security_logs.db');

    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            eventType TEXT NOT NULL,
            details TEXT NOT NULL,
            status TEXT NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> logEvent(String eventType, String details, String status) async {
    final db = await database;
    await db.insert('logs', {
      'timestamp': DateTime.now().toIso8601String(),
      'eventType': eventType,
      'details': details,
      'status': status,
    });
  }

  Future<List<Map<String, dynamic>>> getLogs() async {
    final db = await database;
    return await db.query('logs', orderBy: 'timestamp DESC');
  }
}
