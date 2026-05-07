import '../services/api_service.dart';

class StatsRepository {
  const StatsRepository(this._api);

  final ApiService _api;

  Future<Map<String, dynamic>> getWeeklyStats(
    String weekStart, {
    String? exerciseType,
  }) {
    return _api.getWeeklyStats(weekStart, exerciseType: exerciseType);
  }

  Future<Map<String, dynamic>> getWeeklyHeatmap(
    String weekStart, {
    String? exerciseType,
  }) {
    return _api.getWeeklyHeatmap(weekStart, exerciseType: exerciseType);
  }

  Future<Map<String, dynamic>> getWeeklyBalance(
    String weekStart, {
    String? exerciseType,
  }) {
    return _api.getWeeklyBalance(weekStart, exerciseType: exerciseType);
  }
}
