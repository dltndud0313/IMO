import 'package:get_it/get_it.dart';

import '../ui/home/view_model/home_viewmodel.dart';

final getIt = GetIt.instance;

Future<void> setupDependencies() async {
  if (getIt.isRegistered<HomeViewModel>()) {
    return;
  }

  getIt.registerFactory(HomeViewModel.new);
}
