import 'dart:convert';

import '../../domain/models/workout_session.dart';
import '../dto/session_result_dto.dart';
import '../services/local_db_service.dart';

enum LocalSessionUploadStatus { pending, syncing, synced, failed }

class PendingSessionUpload {
  const PendingSessionUpload({
    required this.sessionId,
    required this.payload,
    required this.retryCount,
  });

  final String sessionId;
  final Map<String, dynamic> payload;
  final int retryCount;
}

class LocalSessionRepository {
  LocalSessionRepository(this._db);

  final LocalDbService _db;

  Future<void> saveSessionResult(
    WorkoutSession session, {
    Map<String, dynamic>? rawPayload,
    LocalSessionUploadStatus uploadStatus = LocalSessionUploadStatus.pending,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = rawPayload ?? session.toJson();

    await _db.upsertWorkoutSession({
      'session_id': session.sessionId,
      'exercise_type': session.exerciseType.wire,
      'status': session.status,
      'end_reason': session.endReason,
      'started_at': session.startedAt.toUtc().toIso8601String(),
      'ended_at': session.endedAt.toUtc().toIso8601String(),
      'duration_sec': session.durationSec,
      'set_count': session.setCount,
      'total_reps': session.totalReps,
      'payload_json': jsonEncode(payload),
      'upload_status': uploadStatus.name,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<WorkoutSession?> getSessionById(String sessionId) async {
    final row = await _db.getWorkoutSession(sessionId);
    return row == null ? null : _sessionFromRow(row);
  }

  Future<List<WorkoutSession>> getSessionsByDate(DateTime date) async {
    final rows = await _db.getWorkoutSessionsByDate(date);
    return rows.map(_sessionFromRow).toList();
  }

  Future<List<WorkoutSession>> getSessionsByMonth(DateTime month) async {
    final rows = await _db.getWorkoutSessionsByMonth(month);
    return rows.map(_sessionFromRow).toList();
  }

  Future<List<PendingSessionUpload>> getPendingUploads() async {
    final rows = await _db.getPendingUploads();
    return rows.map((row) {
      return PendingSessionUpload(
        sessionId: row['session_id'] as String,
        payload: _payloadFromRow(row),
        retryCount: row['retry_count'] as int? ?? 0,
      );
    }).toList();
  }

  Future<void> markSyncing(String sessionId) {
    return _db.updateUploadStatus(
      sessionId,
      LocalSessionUploadStatus.syncing.name,
    );
  }

  Future<void> markSynced(String sessionId) {
    return _db.updateUploadStatus(
      sessionId,
      LocalSessionUploadStatus.synced.name,
      syncedAt: DateTime.now(),
    );
  }

  Future<void> markFailed(String sessionId) {
    return _db.updateUploadStatus(
      sessionId,
      LocalSessionUploadStatus.failed.name,
      incrementRetryCount: true,
    );
  }

  WorkoutSession _sessionFromRow(Map<String, Object?> row) {
    return SessionResultDto.fromJson(_payloadFromRow(row)).toDomain();
  }

  Map<String, dynamic> _payloadFromRow(Map<String, Object?> row) {
    final payloadJson = row['payload_json'] as String? ?? '{}';
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
    throw const FormatException('Invalid local session payload');
  }
}
