import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/routine.dart';
import '../models/session_record.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._();
  static Database? _db;

  /// 현재 로그인한 유저 이메일 (쿼리 필터용)
  String? currentUserEmail;

  DatabaseHelper._();
  factory DatabaseHelper() => _instance;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'muscle_vision.db');
    return openDatabase(
      path,
      version: 3,
      onCreate: (db, _) async {
        await _createSessionsTable(db);
        await _createRoutineTables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createRoutineTables(db);
        }
        if (oldVersion < 3) {
          // 기존 테이블에 user_email 컬럼 추가
          await db.execute(
              "ALTER TABLE sessions ADD COLUMN user_email TEXT NOT NULL DEFAULT ''");
          await db.execute(
              "ALTER TABLE routines ADD COLUMN user_email TEXT NOT NULL DEFAULT ''");
        }
      },
    );
  }

  Future<void> _createSessionsTable(Database db) async {
    await db.execute('''
      CREATE TABLE sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_email TEXT NOT NULL DEFAULT '',
        date TEXT NOT NULL,
        exercise_name TEXT NOT NULL,
        total_reps INTEGER NOT NULL,
        compensation_count INTEGER NOT NULL,
        avg_ch1 REAL NOT NULL,
        avg_ch2 REAL NOT NULL,
        avg_ch3 REAL NOT NULL,
        comment TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createRoutineTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_email TEXT NOT NULL DEFAULT '',
        name TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS routine_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        routine_id INTEGER NOT NULL,
        exercise_id TEXT NOT NULL,
        sets INTEGER NOT NULL,
        target_reps INTEGER NOT NULL,
        rest_seconds INTEGER NOT NULL DEFAULT 60,
        sort_order INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (routine_id) REFERENCES routines(id) ON DELETE CASCADE
      )
    ''');
  }

  String get _email => currentUserEmail ?? '';

  // ──────────────────── Sessions ────────────────────

  Future<int> insertSession(SessionRecord record) async {
    final db = await database;
    final map = record.toMap();
    map['user_email'] = _email;
    return db.insert('sessions', map);
  }

  Future<List<SessionRecord>> getAllSessions() async {
    final db = await database;
    final rows = await db.query('sessions',
        where: 'user_email = ?', whereArgs: [_email], orderBy: 'date DESC');
    return rows.map((r) => SessionRecord.fromMap(r)).toList();
  }

  Future<SessionRecord?> getLastSession() async {
    final db = await database;
    final rows = await db.query('sessions',
        where: 'user_email = ?',
        whereArgs: [_email],
        orderBy: 'date DESC',
        limit: 1);
    if (rows.isEmpty) return null;
    return SessionRecord.fromMap(rows.first);
  }

  Future<List<SessionRecord>> getSessionsAfter(DateTime since) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'user_email = ? AND date >= ?',
      whereArgs: [_email, since.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map((r) => SessionRecord.fromMap(r)).toList();
  }

  Future<List<SessionRecord>> getSessionsByMonth(int year, int month) async {
    final start = DateTime(year, month);
    final end = DateTime(year, month + 1);
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'user_email = ? AND date >= ? AND date < ?',
      whereArgs: [_email, start.toIso8601String(), end.toIso8601String()],
      orderBy: 'date DESC',
    );
    return rows.map((r) => SessionRecord.fromMap(r)).toList();
  }

  Future<List<SessionRecord>> getSessionsByExercise(
      String exerciseName) async {
    final db = await database;
    final rows = await db.query(
      'sessions',
      where: 'user_email = ? AND exercise_name = ?',
      whereArgs: [_email, exerciseName],
      orderBy: 'date DESC',
    );
    return rows.map((r) => SessionRecord.fromMap(r)).toList();
  }

  Future<int> deleteSession(int id) async {
    final db = await database;
    return db.delete('sessions',
        where: 'id = ? AND user_email = ?', whereArgs: [id, _email]);
  }

  /// 연속 운동 일수 계산.
  Future<int> getStreakDays() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT DISTINCT date(date) AS d FROM sessions WHERE user_email = ? ORDER BY d DESC',
      [_email],
    );
    if (rows.isEmpty) return 0;

    int streak = 0;
    var expected = DateTime.now();
    for (final row in rows) {
      final d = DateTime.tryParse(row['d'] as String);
      if (d == null) continue;
      final diff = DateTime(expected.year, expected.month, expected.day)
          .difference(DateTime(d.year, d.month, d.day))
          .inDays;
      if (diff == 0 || diff == 1) {
        streak++;
        expected = d;
      } else {
        break;
      }
    }
    return streak;
  }

  /// 이번 주(월~일) 통계.
  Future<Map<String, dynamic>> getWeeklyStats() async {
    final now = DateTime.now();
    final weekday = now.weekday; // 1=Mon
    final monday = DateTime(now.year, now.month, now.day - (weekday - 1));
    final sessions = await getSessionsAfter(monday);

    int totalReps = 0;
    int totalComp = 0;
    for (final s in sessions) {
      totalReps += s.totalReps;
      totalComp += s.compensationCount;
    }
    return {
      'sessionCount': sessions.length,
      'totalReps': totalReps,
      'totalComp': totalComp,
    };
  }

  // ──────────────────── Routines ────────────────────

  Future<int> insertRoutine(Routine routine) async {
    final db = await database;
    final map = routine.toMap();
    map['user_email'] = _email;
    final routineId = await db.insert('routines', map);
    for (var i = 0; i < routine.items.length; i++) {
      final item = routine.items[i].copyWith(
        routineId: routineId,
        sortOrder: i,
      );
      await db.insert('routine_items', item.toMap());
    }
    return routineId;
  }

  Future<void> updateRoutine(Routine routine) async {
    if (routine.id == null) return;
    final db = await database;
    await db.update(
      'routines',
      {'name': routine.name},
      where: 'id = ? AND user_email = ?',
      whereArgs: [routine.id, _email],
    );
    await db.delete('routine_items',
        where: 'routine_id = ?', whereArgs: [routine.id]);
    for (var i = 0; i < routine.items.length; i++) {
      final item = routine.items[i].copyWith(
        routineId: routine.id,
        sortOrder: i,
      );
      await db.insert('routine_items', item.toMap());
    }
  }

  Future<List<Routine>> getAllRoutines() async {
    final db = await database;
    final routineRows = await db.query('routines',
        where: 'user_email = ?',
        whereArgs: [_email],
        orderBy: 'created_at DESC');
    final routines = <Routine>[];
    for (final row in routineRows) {
      final id = row['id'] as int;
      final itemRows = await db.query(
        'routine_items',
        where: 'routine_id = ?',
        whereArgs: [id],
        orderBy: 'sort_order ASC',
      );
      final items = itemRows.map((r) => RoutineItem.fromMap(r)).toList();
      routines.add(Routine.fromMap(row, items: items));
    }
    return routines;
  }

  Future<Routine?> getRoutine(int id) async {
    final db = await database;
    final rows = await db.query('routines',
        where: 'id = ? AND user_email = ?', whereArgs: [id, _email]);
    if (rows.isEmpty) return null;
    final itemRows = await db.query(
      'routine_items',
      where: 'routine_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order ASC',
    );
    final items = itemRows.map((r) => RoutineItem.fromMap(r)).toList();
    return Routine.fromMap(rows.first, items: items);
  }

  Future<int> deleteRoutine(int id) async {
    final db = await database;
    await db.delete('routine_items',
        where: 'routine_id = ?', whereArgs: [id]);
    return db.delete('routines',
        where: 'id = ? AND user_email = ?', whereArgs: [id, _email]);
  }
}
