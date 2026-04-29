import 'package:get_it/get_it.dart';

import '../data/services/pi_socket_service.dart';
import '../ui/home/view_model/home_viewmodel.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  if (getIt.isRegistered<HomeViewModel>()) {
    return;
  }

  getIt.registerLazySingleton(PiSocketService.new);
  getIt.registerFactory(HomeViewModel.new);
}
