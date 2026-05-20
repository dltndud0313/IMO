import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../data/services/pi_message.dart';
import '../../../data/services/pi_socket_service.dart';

enum GameStatusTone { normal, warning, danger, success }

class GameViewModel extends ChangeNotifier {
  GameViewModel(this._piSocketService) {
    _initialize();
  }

  final PiSocketService _piSocketService;

  static const double boardWidth = 960;
  static const double boardHeight = 540;
  static const int preparationSeconds = 15;

  final List<_GameLevelConfig> _levels = const [
    _GameLevelConfig(rows: 4, cols: 7, ballSpeed: 5.0, brickColor: Color(0xFF6DF2D6)),
    _GameLevelConfig(rows: 5, cols: 8, ballSpeed: 5.7, brickColor: Color(0xFFD8FF7D)),
    _GameLevelConfig(rows: 6, cols: 9, ballSpeed: 6.3, brickColor: Color(0xFFFF9D7F)),
  ];

  StreamSubscription<PiSocketConnectionState>? _connectionSubscription;
  StreamSubscription<ConnectionStatusMessage>? _connectionStatusSubscription;
  StreamSubscription<SensorFrameMessage>? _sensorSubscription;
  Timer? _gameLoopTimer;
  Timer? _preparationTicker;
  Timer? _reconnectTimer;

  bool _disposed = false;
  DateTime? _lastTickAt;
  DateTime _preparationEndsAt = DateTime.now();
  bool _hasStartedGame = false;

  final List<_ArmFrame> _stablePreparationFrames = <_ArmFrame>[];
  final List<_ArmFrame> _allPreparationFrames = <_ArmFrame>[];
  _ArmFrame? _previousPreparationFrame;
  _ArmFrame? _latestFrame;
  List<List<double>>? _baselineAccels;
  List<List<double>>? _baselineGyros;

  PiSocketConnectionState _socketState = PiSocketConnectionState.disconnected;
  bool _esp32Connected = false;
  String _frameStatus = 'frame waiting';

  _GamePhase _phase = _GamePhase.preparing;
  double _leftScore = 0;
  double _rightScore = 0;
  bool _leftRaised = false;
  bool _rightRaised = false;
  DateTime? _bothRaisedSince;

  int _levelIndex = 0;
  int _score = 0;
  int _lives = 3;
  final _GamePaddle _paddle = _GamePaddle();
  final _GameBall _ball = _GameBall();
  List<_GameBrick> _bricks = <_GameBrick>[];

  bool get isConnected => _socketState == PiSocketConnectionState.connected;
  bool get esp32Connected => _esp32Connected;
  bool get showPreparationScreen =>
      !_hasStartedGame && (_phase == _GamePhase.preparing || _phase == _GamePhase.armed);
  bool get showBoardOverlay => !showPreparationScreen && _phase != _GamePhase.running;
  bool get isPreparing => _phase == _GamePhase.preparing;
  bool get isArmed => _phase == _GamePhase.armed;
  bool get isRunning => _phase == _GamePhase.running;
  bool get isGameOver => _phase == _GamePhase.gameOver;
  bool get isVictory => _phase == _GamePhase.victory;

  int get displayLevel => _levelIndex + 1;
  int get score => _score;
  int get lives => _lives;
  double get leftScore => _leftScore;
  double get rightScore => _rightScore;
  String get frameStatus => _frameStatus;

  String get connectionLabel {
    if (_socketState == PiSocketConnectionState.connecting) {
      return '연결 중';
    }
    if (!isConnected) {
      return '오프라인';
    }
    if (!_esp32Connected) {
      return '센서 대기';
    }
    return '센서 연결됨';
  }

  String get connectionDetail {
    if (!isConnected) {
      return 'Pi WebSocket 연결을 확인하세요.';
    }
    if (!_esp32Connected) {
      return 'ESP32 센서 입력을 기다리는 중입니다.';
    }
    return _frameStatus;
  }

  String get preparationTitle =>
      isPreparing ? '자세를 준비하세요' : '준비됐으면 시작하세요';

  String get preparationDescription {
    if (isPreparing) {
      return '15초 동안 양팔을 편하게 내린 기본 자세를 유지하면\n시작 기준점을 자동으로 잡습니다.';
    }
    return '두 팔을 동시에 들어 올리면 게임 화면으로 전환되며\n즉시 게임이 시작됩니다.';
  }

  String get preparationCountdown {
    if (!isPreparing) {
      return '';
    }
    final remainingMs = _preparationEndsAt.difference(DateTime.now()).inMilliseconds;
    final remainingSec = math.max(0, (remainingMs / 1000).ceil());
    return '$remainingSec';
  }

  double get startHoldProgress {
    if (_bothRaisedSince == null) {
      return 0.0;
    }
    final elapsed = DateTime.now().difference(_bothRaisedSince!).inMilliseconds;
    return (elapsed / _requiredStartHoldMs).clamp(0.0, 1.0);
  }

  String get liveInputHint => '왼팔과 오른팔 IMU만 사용합니다.';

  String get gameplayHint {
    return switch (_phase) {
      _GamePhase.preparing => '기준 자세를 유지하면서 카운트다운을 기다리세요.',
      _GamePhase.armed => '양팔을 동시에 들어 올리면 시작합니다.',
      _GamePhase.running => '왼팔은 왼쪽, 오른팔은 오른쪽, 양팔은 가운데 패들을 선택합니다.',
      _GamePhase.levelReady => '다음 레벨입니다. 양팔을 들어 다시 시작하세요.',
      _GamePhase.victory => '모든 레벨을 클리어했습니다. 양팔을 들면 처음부터 다시 시작합니다.',
      _GamePhase.gameOver => '남은 라이프가 없습니다. 양팔을 들면 다시 시작합니다.',
    };
  }

  String get boardOverlayTitle {
    return switch (_phase) {
      _GamePhase.levelReady => '다음 레벨 준비',
      _GamePhase.victory => '클리어',
      _GamePhase.gameOver => '게임 오버',
      _ => '',
    };
  }

  String get boardOverlayMessage {
    return switch (_phase) {
      _GamePhase.levelReady => '양팔을 동시에 들어 다음 레벨을 시작하세요.',
      _GamePhase.victory => '양팔을 동시에 들면 1레벨부터 다시 시작합니다.',
      _GamePhase.gameOver => '양팔을 동시에 들면 다시 도전할 수 있습니다.',
      _ => '',
    };
  }

  GameStatusTone get statusTone {
    if (!isConnected || !_esp32Connected) {
      return GameStatusTone.warning;
    }
    return switch (_phase) {
      _GamePhase.preparing => GameStatusTone.normal,
      _GamePhase.armed => GameStatusTone.success,
      _GamePhase.running => GameStatusTone.normal,
      _GamePhase.levelReady => GameStatusTone.success,
      _GamePhase.victory => GameStatusTone.success,
      _GamePhase.gameOver => GameStatusTone.danger,
    };
  }

  GameBoardSnapshot get board => GameBoardSnapshot(
        width: boardWidth,
        height: boardHeight,
        bricks: _bricks
            .where((brick) => brick.alive)
            .map(
              (brick) => GameBrickSnapshot(
                x: brick.x,
                y: brick.y,
                width: brick.width,
                height: brick.height,
              ),
            )
            .toList(growable: false),
        paddle: GamePaddleSnapshot(
          x: _paddle.x,
          y: _paddle.y,
          width: _paddle.width,
          height: _paddle.height,
          activeIndex: _paddle.activeIndex,
        ),
        ball: GameBallSnapshot(
          x: _ball.x,
          y: _ball.y,
          radius: _ball.radius,
          stuck: _ball.stuck,
        ),
        brickColor: _levels[_levelIndex].brickColor,
      );

  void _initialize() {
    _loadLevel(0);
    _startPreparation(resetBaseline: true);
    _startGameLoop();
    _startPreparationTicker();

    _connectionSubscription = _piSocketService.connectionState.listen(
      _handleSocketState,
    );
    _connectionStatusSubscription =
        _piSocketService.messagesOf<ConnectionStatusMessage>().listen(
      (message) {
        _esp32Connected = message.esp32Connected;
        _safeNotify();
      },
    );
    _sensorSubscription = _piSocketService.messagesOf<SensorFrameMessage>().listen(
      _handleSensorFrame,
    );

    unawaited(_ensureConnected());
  }

  Future<void> _ensureConnected() async {
    if (_disposed || _piSocketService.isConnected) {
      return;
    }
    try {
      await _piSocketService.connect();
    } catch (_) {
      _scheduleReconnect();
    }
  }

  void _handleSocketState(PiSocketConnectionState state) {
    _socketState = state;
    if (state == PiSocketConnectionState.connected) {
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } else if (!_disposed) {
      _scheduleReconnect();
    }
    _safeNotify();
  }

  void _scheduleReconnect() {
    if (_disposed || _reconnectTimer != null) {
      return;
    }
    _reconnectTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      if (_piSocketService.isConnected) {
        timer.cancel();
        _reconnectTimer = null;
        return;
      }
      unawaited(_ensureConnected());
    });
  }

  void _startGameLoop() {
    _gameLoopTimer?.cancel();
    _gameLoopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      if (_phase != _GamePhase.running) {
        return;
      }

      final now = DateTime.now();
      final last = _lastTickAt;
      _lastTickAt = now;
      final deltaMs = last == null ? 16.0 : now.difference(last).inMilliseconds.toDouble();

      _updateBall(deltaMs);
      _updateBricks();
      _safeNotify();
    });
  }

  void _startPreparationTicker() {
    _preparationTicker?.cancel();
    _preparationTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (_phase == _GamePhase.preparing &&
          DateTime.now().isAfter(_preparationEndsAt)) {
        _completePreparation();
      }
      _safeNotify();
    });
  }

  void _handleSensorFrame(SensorFrameMessage message) {
    if (message.imus.length < 2) {
      return;
    }

    _frameStatus = 'seq ${message.seq} / ts ${message.timestampMs}ms';
    final frame = _ArmFrame.fromMessage(message);
    _latestFrame = frame;

    if (_phase == _GamePhase.preparing) {
      _collectPreparationFrame(frame);
      if (DateTime.now().isAfter(_preparationEndsAt)) {
        _completePreparation();
      }
      _safeNotify();
      return;
    }

    if (_baselineAccels == null || _baselineGyros == null) {
      _finalizePreparationBaseline();
    }

    _updateArmScores(frame);
    _updateControlFromScores();

    if (_phase == _GamePhase.armed || _phase == _GamePhase.levelReady) {
      _handleTwoArmStart(_startRound);
    } else if (_phase == _GamePhase.victory || _phase == _GamePhase.gameOver) {
      _handleTwoArmStart(_restartSession);
    }

    _safeNotify();
  }

  void _collectPreparationFrame(_ArmFrame frame) {
    _appendCapped(_allPreparationFrames, frame, maxLength: 240);

    if (_previousPreparationFrame == null) {
      _previousPreparationFrame = frame;
      return;
    }

    final armAccelDrift =
        _vectorDeltaNorm(frame.accels[0], _previousPreparationFrame!.accels[0]) +
        _vectorDeltaNorm(frame.accels[1], _previousPreparationFrame!.accels[1]);
    final armGyroDrift =
        _vectorDeltaNorm(frame.gyros[0], _previousPreparationFrame!.gyros[0]) +
        _vectorDeltaNorm(frame.gyros[1], _previousPreparationFrame!.gyros[1]);

    final stableNow = armAccelDrift <= 0.10 && armGyroDrift <= 1.8;
    if (stableNow) {
      _appendCapped(_stablePreparationFrames, frame, maxLength: 180);
    }
    _previousPreparationFrame = frame;
  }

  void _startPreparation({required bool resetBaseline}) {
    if (resetBaseline) {
      _baselineAccels = null;
      _baselineGyros = null;
    }
    _preparationEndsAt =
        DateTime.now().add(const Duration(seconds: preparationSeconds));
    _phase = _GamePhase.preparing;
    _bothRaisedSince = null;
    _stablePreparationFrames.clear();
    _allPreparationFrames.clear();
    _previousPreparationFrame = null;
    _leftScore = 0;
    _rightScore = 0;
    _leftRaised = false;
    _rightRaised = false;
    _attachBallToPaddle();
    _safeNotify();
  }

  void _completePreparation() {
    if (_phase != _GamePhase.preparing) {
      return;
    }
    _finalizePreparationBaseline();
    _phase = _GamePhase.armed;
    _bothRaisedSince = null;
  }

  void _finalizePreparationBaseline() {
    final source = _stablePreparationFrames.length >= 20
        ? _stablePreparationFrames
        : (_allPreparationFrames.isNotEmpty
            ? _allPreparationFrames
            : (_latestFrame == null ? const <_ArmFrame>[] : <_ArmFrame>[_latestFrame!]));

    if (source.isEmpty) {
      _baselineAccels = const [
        [0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0],
      ];
      _baselineGyros = const [
        [0.0, 0.0, 0.0],
        [0.0, 0.0, 0.0],
      ];
      return;
    }

    _baselineAccels = _meanArmFrames(source, (frame) => frame.accels);
    _baselineGyros = _meanArmFrames(source, (frame) => frame.gyros);
  }

  void _updateArmScores(_ArmFrame frame) {
    if (_baselineAccels == null || _baselineGyros == null) {
      _leftScore = 0;
      _rightScore = 0;
      _leftRaised = false;
      _rightRaised = false;
      return;
    }

    final rawLeft = _armScore(
      frame.accels[0],
      _baselineAccels![0],
      frame.gyros[0],
      _baselineGyros![0],
    );
    final rawRight = _armScore(
      frame.accels[1],
      _baselineAccels![1],
      frame.gyros[1],
      _baselineGyros![1],
    );

    _leftScore = _blendScore(_leftScore, rawLeft);
    _rightScore = _blendScore(_rightScore, rawRight);
    _leftRaised = _leftScore >= 0.34;
    _rightRaised = _rightScore >= 0.34;
  }

  void _updateControlFromScores() {
    if (_leftRaised && _rightRaised) {
      _paddle.activeIndex = 1;
    } else if (_leftRaised && !_rightRaised) {
      _paddle.activeIndex = 0;
    } else if (_rightRaised && !_leftRaised) {
      _paddle.activeIndex = 2;
    } else {
      _paddle.activeIndex = 1;
    }
    if (_ball.stuck) {
      _attachBallToPaddle();
    }
  }

  void _handleTwoArmStart(VoidCallback action) {
    final bothRaisedForStart = _leftScore >= 0.58 && _rightScore >= 0.58;
    if (!bothRaisedForStart) {
      _bothRaisedSince = null;
      return;
    }

    final now = DateTime.now();
    _bothRaisedSince ??= now;
    final heldMs = now.difference(_bothRaisedSince!).inMilliseconds;
    if (heldMs >= _requiredStartHoldMs) {
      _bothRaisedSince = null;
      action();
    }
  }

  void _startRound() {
    final speed = _levels[_levelIndex].ballSpeed;
    _paddle.activeIndex = 1;
    _attachBallToPaddle();
    _ball.vx = speed * 0.75;
    _ball.vy = -speed;
    _ball.stuck = false;
    _phase = _GamePhase.running;
    _hasStartedGame = true;
  }

  void _restartSession() {
    _score = 0;
    _lives = 3;
    _hasStartedGame = false;
    _loadLevel(0);
    _startPreparation(resetBaseline: true);
  }

  void _loadLevel(int index) {
    _levelIndex = index;
    _bricks = _buildBricks(_levels[index]);
    _paddle.width = boardWidth * 0.62;
    _paddle.height = 26;
    _paddle.x = (boardWidth - _paddle.width) / 2;
    _paddle.y = boardHeight - 46;
    _paddle.activeIndex = 1;
    _attachBallToPaddle();
  }

  List<_GameBrick> _buildBricks(_GameLevelConfig config) {
    const top = 66.0;
    const side = 44.0;
    const gap = 10.0;
    const brickHeight = 22.0;
    final totalWidth = boardWidth - side * 2;
    final brickWidth = (totalWidth - gap * (config.cols - 1)) / config.cols;
    final bricks = <_GameBrick>[];

    for (var row = 0; row < config.rows; row++) {
      for (var col = 0; col < config.cols; col++) {
        bricks.add(
          _GameBrick(
            x: side + col * (brickWidth + gap),
            y: top + row * (brickHeight + gap),
            width: brickWidth,
            height: brickHeight,
          ),
        );
      }
    }
    return bricks;
  }

  void _attachBallToPaddle() {
    final segmentWidth = _paddle.width / 3;
    _ball.radius = 9;
    _ball.x = _paddle.x + segmentWidth * (_paddle.activeIndex + 0.5);
    _ball.y = _paddle.y - _ball.radius - 4;
    _ball.vx = 0;
    _ball.vy = 0;
    _ball.stuck = true;
  }

  void _updateBall(double deltaMs) {
    final moveScale = deltaMs / 16.0;
    _ball.x += _ball.vx * moveScale;
    _ball.y += _ball.vy * moveScale;

    if (_ball.x <= 22 || _ball.x >= boardWidth - 22) {
      _ball.vx *= -1;
      _ball.x = _clamp(_ball.x, 22, boardWidth - 22);
    }

    if (_ball.y <= 26) {
      _ball.vy *= -1;
      _ball.y = 26;
    }

    final hitPaddle = _ball.y + _ball.radius >= _paddle.y &&
        _ball.y - _ball.radius <= _paddle.y + _paddle.height &&
        _ball.x >= _paddle.x &&
        _ball.x <= _paddle.x + _paddle.width &&
        _ball.vy > 0;

    if (hitPaddle) {
      final segmentWidth = _paddle.width / 3;
      final segmentIndex = _clampInt(
        ((_ball.x - _paddle.x) / segmentWidth).floor(),
        0,
        2,
      );

      if (segmentIndex == _paddle.activeIndex) {
        final segmentCenter = _paddle.x + segmentWidth * (segmentIndex + 0.5);
        final localRatio = (_ball.x - segmentCenter) / (segmentWidth / 2);
        _ball.vx = _clamp(localRatio * 4.8 + (segmentIndex - 1) * 1.2, -6.6, 6.6);
        _ball.vy = -_ball.vy.abs();
      } else {
        _loseLife();
        return;
      }
    }

    if (_ball.y - _ball.radius > boardHeight) {
      _loseLife();
    }
  }

  void _updateBricks() {
    var aliveCount = 0;
    for (final brick in _bricks) {
      if (!brick.alive) {
        continue;
      }
      aliveCount += 1;
      final withinX = _ball.x + _ball.radius >= brick.x &&
          _ball.x - _ball.radius <= brick.x + brick.width;
      final withinY = _ball.y + _ball.radius >= brick.y &&
          _ball.y - _ball.radius <= brick.y + brick.height;

      if (withinX && withinY) {
        brick.alive = false;
        aliveCount -= 1;
        _score += 15;
        _ball.vy *= -1;
      }
    }

    if (aliveCount == 0 && _phase == _GamePhase.running) {
      _advanceLevelOrWin();
    }
  }

  void _advanceLevelOrWin() {
    if (_levelIndex + 1 >= _levels.length) {
      _phase = _GamePhase.victory;
      _attachBallToPaddle();
      return;
    }

    _loadLevel(_levelIndex + 1);
    _phase = _GamePhase.levelReady;
  }

  void _loseLife() {
    _lives = math.max(0, _lives - 1);
    if (_lives <= 0) {
      _phase = _GamePhase.gameOver;
      _attachBallToPaddle();
      return;
    }

    _attachBallToPaddle();
    _phase = _GamePhase.levelReady;
  }

  double _armScore(
    List<double> accel,
    List<double> accelBaseline,
    List<double> gyro,
    List<double> gyroBaseline,
  ) {
    final accelDelta = _vectorDeltaNorm(accel, accelBaseline);
    final gyroDelta = _vectorDeltaNorm(gyro, gyroBaseline);
    return accelDelta + gyroDelta * 0.035;
  }

  double _blendScore(double previous, double next) {
    return previous * 0.58 + next * 0.42;
  }

  double _vectorDeltaNorm(List<double> current, List<double> baseline) {
    return (current[0] - baseline[0]).abs() +
        (current[1] - baseline[1]).abs() +
        (current[2] - baseline[2]).abs();
  }

  List<List<double>> _meanArmFrames(
    List<_ArmFrame> frames,
    List<List<double>> Function(_ArmFrame frame) extractor,
  ) {
    final sums = List<List<double>>.generate(
      2,
      (_) => List<double>.filled(3, 0),
      growable: false,
    );

    for (final frame in frames) {
      final values = extractor(frame);
      for (var arm = 0; arm < 2; arm++) {
        for (var axis = 0; axis < 3; axis++) {
          sums[arm][axis] += values[arm][axis];
        }
      }
    }

    return sums
        .map(
          (row) => row
              .map((value) => value / frames.length)
              .toList(growable: false),
        )
        .toList(growable: false);
  }

  void _appendCapped<T>(List<T> list, T value, {required int maxLength}) {
    list.add(value);
    if (list.length > maxLength) {
      list.removeAt(0);
    }
  }

  double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  int _clampInt(int value, int min, int max) {
    return math.max(min, math.min(max, value));
  }

  void _safeNotify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _connectionSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _sensorSubscription?.cancel();
    _gameLoopTimer?.cancel();
    _preparationTicker?.cancel();
    _reconnectTimer?.cancel();
    super.dispose();
  }
}

class GameBoardSnapshot {
  const GameBoardSnapshot({
    required this.width,
    required this.height,
    required this.bricks,
    required this.paddle,
    required this.ball,
    required this.brickColor,
  });

  final double width;
  final double height;
  final List<GameBrickSnapshot> bricks;
  final GamePaddleSnapshot paddle;
  final GameBallSnapshot ball;
  final Color brickColor;
}

class GameBrickSnapshot {
  const GameBrickSnapshot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
}

class GamePaddleSnapshot {
  const GamePaddleSnapshot({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.activeIndex,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  final int activeIndex;
}

class GameBallSnapshot {
  const GameBallSnapshot({
    required this.x,
    required this.y,
    required this.radius,
    required this.stuck,
  });

  final double x;
  final double y;
  final double radius;
  final bool stuck;
}

enum _GamePhase { preparing, armed, running, levelReady, victory, gameOver }

class _GameLevelConfig {
  const _GameLevelConfig({
    required this.rows,
    required this.cols,
    required this.ballSpeed,
    required this.brickColor,
  });

  final int rows;
  final int cols;
  final double ballSpeed;
  final Color brickColor;
}

class _GameBrick {
  _GameBrick({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;
  bool alive = true;
}

class _GamePaddle {
  double x = 0;
  double y = 0;
  double width = 0;
  double height = 0;
  int activeIndex = 1;
}

class _GameBall {
  double x = GameViewModel.boardWidth / 2;
  double y = GameViewModel.boardHeight - 70;
  double vx = 0;
  double vy = 0;
  double radius = 9;
  bool stuck = true;
}

class _ArmFrame {
  const _ArmFrame({
    required this.accels,
    required this.gyros,
  });

  factory _ArmFrame.fromMessage(SensorFrameMessage message) {
    SensorFrameImuSample pickArmImu({
      required int preferredIndex,
      required int fallbackPosition,
    }) {
      for (final imu in message.imus) {
        if (imu.index == preferredIndex) {
          return imu;
        }
      }
      return message.imus[fallbackPosition];
    }

    final leftImu = pickArmImu(preferredIndex: 1, fallbackPosition: 0);
    final rightImu = pickArmImu(
      preferredIndex: 2,
      fallbackPosition: message.imus.length > 1 ? 1 : 0,
    );

    return _ArmFrame(
      accels: [
        List<double>.from(leftImu.accel),
        List<double>.from(rightImu.accel),
      ],
      gyros: [
        List<double>.from(leftImu.gyro),
        List<double>.from(rightImu.gyro),
      ],
    );
  }

  final List<List<double>> accels;
  final List<List<double>> gyros;
}

const int _requiredStartHoldMs = 350;
