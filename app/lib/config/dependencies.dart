import 'package:get_it/get_it.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/repositories/auth_repository.dart';
import '../data/services/api_service.dart';
import '../data/services/auth_service.dart';
import '../data/services/pi_socket_service.dart';
import '../data/services/shared_prefs_service.dart';
import '../data/repositories/calibration_repository.dart';
import '../data/repositories/device_connection_repository.dart';
import '../data/repositories/user_profile_repository.dart';
import '../data/repositories/workout_repository.dart';
import '../ui/home/view_model/home_viewmodel.dart';

final getIt = GetIt.instance;

const _authDioName = 'authDio';
const _apiDioName = 'apiDio';

Future<void> setupDependencies() async {
  if (getIt.isRegistered<HomeViewModel>()) {
    return;
  }

  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton(
    () => SharedPrefsService(sharedPreferences),
  );

  getIt.registerLazySingleton<Dio>(
    _buildBaseDio,
    instanceName: _authDioName,
  );
  getIt.registerLazySingleton<Dio>(
    _buildApiDio,
    instanceName: _apiDioName,
  );
  getIt.registerLazySingleton(
    () => AuthService(getIt<Dio>(instanceName: _authDioName)),
  );
  getIt.registerLazySingleton(
    () => AuthRepository(getIt<AuthService>(), getIt<SharedPrefsService>()),
  );
  getIt.registerLazySingleton(
    () => ApiService(getIt<Dio>(instanceName: _apiDioName)),
  );
  getIt.registerLazySingleton(
    () => UserProfileRepository(getIt<ApiService>()),
  );
  getIt.registerLazySingleton(PiSocketService.new);
  getIt.registerLazySingleton(() => WorkoutRepository(getIt<PiSocketService>()));
  getIt.registerLazySingleton(
    () => CalibrationRepository(getIt<PiSocketService>()),
  );
  getIt.registerLazySingleton(
    () => DeviceConnectionRepository(getIt<PiSocketService>()),
  );
  getIt.registerFactory(HomeViewModel.new);

  await getIt<AuthRepository>().init();
}

Dio _buildBaseDio() {
  return Dio(
    BaseOptions(
      baseUrl: backendApiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );
}

Dio _buildApiDio() {
  final dio = _buildBaseDio();

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = getIt<SharedPrefsService>().getAccessToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
      onError: (error, handler) async {
        final alreadyRetried = error.requestOptions.extra['authRetried'] == true;
        if (error.response?.statusCode == 401 && !alreadyRetried) {
          final newToken = await getIt<AuthRepository>().refreshToken();
          if (newToken != null && newToken.isNotEmpty) {
            final requestOptions = error.requestOptions;
            requestOptions.extra['authRetried'] = true;
            requestOptions.headers['Authorization'] = 'Bearer $newToken';
            try {
              final response = await dio.fetch<dynamic>(requestOptions);
              return handler.resolve(response);
            } catch (_) {
              // Fall through to the original 401 when retry also fails.
            }
          }
        }
        handler.next(error);
      },
    ),
  );

  return dio;
}
