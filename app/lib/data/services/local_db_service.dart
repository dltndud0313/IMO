import 'package:path/path.dart' as path_package;
import 'package:sqflite/sqflite.dart';

class LocalDbService {
  static const databaseName = 'imo_local.db';
  static const databaseVersion = 1;
  static const workoutSessionsTable = 'workout_sessions_local';

  Database? _database;

  Future<void> init() async {
    if (_database != null) {
      return;
    }

    final databasePath = await getDatabasesPath();
    final fullPath = path_package.join(databasePath, databaseName);
    _database = await openDatabase(
      fullPath,
      version: databaseVersion,
      onCreate: _createSchema,
    );
  }

  Future<Database> get database async {
    await init();
    return _database!;
  }

  Future<void> upsertWorkoutSession(Map<String, Object?> row) async {
    final db = await database;
    await db.insert(
      workoutSessionsTable,
      row,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, Object?>?> getWorkoutSession(String sessionId) async {
    final db = await database;
    final rows = await db.query(
      workoutSessionsTable,
      where: 'session_id = ?',
      whereArgs: [sessionId],
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> getWorkoutSessionsByDate(
    DateTime date,
  ) async {
    return _queryWorkoutSessionsBetween(
      DateTime(date.year, date.month, date.day),
      DateTime(date.year, date.month, date.day + 1),
    );
  }

  Future<List<Map<String, Object?>>> getWorkoutSessionsByMonth(
    DateTime month,
  ) async {
    return _queryWorkoutSessionsBetween(
      DateTime(month.year, month.month),
      DateTime(month.year, month.month + 1),
    );
  }

  Future<List<Map<String, Object?>>> getPendingUploads() async {
    final db = await database;
    return db.query(
      workoutSessionsTable,
      where: 'upload_status IN (?, ?)',
      whereArgs: ['pending', 'failed'],
      orderBy: 'created_at ASC',
    );
  }

  Future<void> updateUploadStatus(
    String sessionId,
    String status, {
    DateTime? syncedAt,
    bool incrementRetryCount = false,
  }) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE $workoutSessionsTable
      SET upload_status = ?,
          synced_at = ?,
          retry_count = retry_count + ?,
          updated_at = ?
      WHERE session_id = ?
      ''',
      [
        status,
        syncedAt?.toUtc().toIso8601String(),
        incrementRetryCount ? 1 : 0,
        DateTime.now().toUtc().toIso8601String(),
        sessionId,
      ],
    );
  }

  Future<List<Map<String, Object?>>> _queryWorkoutSessionsBetween(
    DateTime start,
    DateTime end,
  ) async {
    final db = await database;
    return db.query(
      workoutSessionsTable,
      where: 'started_at >= ? AND started_at < ?',
      whereArgs: [
        start.toUtc().toIso8601String(),
        end.toUtc().toIso8601String(),
      ],
      orderBy: 'started_at DESC',
    );
  }

  Future<void> _createSchema(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $workoutSessionsTable (
        session_id TEXT PRIMARY KEY,
        exercise_type TEXT NOT NULL,
        status TEXT NOT NULL,
        end_reason TEXT,
        started_at TEXT NOT NULL,
        ended_at TEXT NOT NULL,
        duration_sec INTEGER NOT NULL DEFAULT 0,
        set_count INTEGER NOT NULL DEFAULT 0,
        total_reps INTEGER NOT NULL DEFAULT 0,
        payload_json TEXT NOT NULL,
        upload_status TEXT NOT NULL DEFAULT 'pending',
        synced_at TEXT,
        retry_count INTEGER NOT NULL DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_workout_sessions_started_at
      ON $workoutSessionsTable(started_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_workout_sessions_exercise_started
      ON $workoutSessionsTable(exercise_type, started_at DESC)
    ''');

    await db.execute('''
      CREATE INDEX idx_workout_sessions_upload_status
      ON $workoutSessionsTable(upload_status)
    ''');
  }
}
