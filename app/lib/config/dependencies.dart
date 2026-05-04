import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';

import '../data/services/api_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/pi_socket_service.dart';
import '../data/repositories/calibration_repository.dart';
import '../data/repositories/device_connection_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../ui/home/view_model/home_viewmodel.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  if (getIt.isRegistered<HomeViewModel>()) {
    return;
  }

  getIt.registerLazySingleton<Dio>(
    () => Dio(
      BaseOptions(
        baseUrl: backendApiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    ),
  );
  getIt.registerLazySingleton(() => ApiService(getIt<Dio>()));
  getIt.registerLazySingleton(() => AuthService(getIt<Dio>()));
  getIt.registerLazySingleton(PiSocketService.new);
  getIt.registerLazySingleton(() => WorkoutRepository(getIt<PiSocketService>()));
  getIt.registerLazySingleton(
    () => CalibrationRepository(getIt<PiSocketService>()),
  );
  getIt.registerLazySingleton(
    () => DeviceConnectionRepository(getIt<PiSocketService>()),
  );
  getIt.registerFactory(HomeViewModel.new);
}
