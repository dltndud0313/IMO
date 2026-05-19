import 'package:flutter/foundation.dart';

import '../../../data/services/pi_socket_service.dart';

class GameViewModel extends ChangeNotifier {
  GameViewModel(this._piSocketService);

  final PiSocketService _piSocketService;

  bool get isConnected => _piSocketService.isConnected;

  // TODO: 게임 로직 추가
}
