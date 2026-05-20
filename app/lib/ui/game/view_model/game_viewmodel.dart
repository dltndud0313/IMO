import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../data/services/pi_message.dart';
import '../../../data/services/pi_socket_service.dart';

enum GameStatusTone { normal, warning, danger, success }

class GameViewModel extends ChangeNotifier {
  GameViewModel(this._piSocketService) {
    _initialize();
  }

  final PiSocketService _piSocketService;

  static const double boardWidth = 840;
  static const double boardHeight = 760;

  final List<_GameLevelConfig> _levels = const [
    _GameLevelConfig(rows: 4, cols: 6, ballSpeed: 4.2, brickColor: Color(0xFF6DF2D6)),
    _GameLevelConfig(rows: 5, cols: 8, ballSpeed: 5.1, brickColor: Color(0xFFD8FF7D)),
    _GameLevelConfig(rows: 6, cols: 10, ballSpeed: 6.2, brickColor: Color(0xFFFF9D7F)),
  ];

  StreamSubscription<PiSocketConnectionState>? _connectionSubscription;
  StreamSubscription<SensorFrameMessage>? _sensorSubscription;
  StreamSubscription<ConnectionStatusMessage>? _connectionStatusSubscription;
  Timer? _loopTimer;
  Timer? _reconnectTimer;
  DateTime? _lastTickAt;
  bool _disposed = false;

  final _baselineFrames = <_BaselineFrame>[];
  _BaselineFrame? _previousFrame;
  List<List<double>>? _baselineAccels;
  List<List<double>>? _baselineGyros;
  bool _baselineReady = false;
  int _stableCount = 0;

  PiSocketConnectionState _socketState = PiSocketConnectionState.disconnected;
  bool _esp32Connected = false;
  String _frameStatus = 'frame waiting';
  String _statusMessage = '센서 연결과 baseline 측정을 기다리는 중입니다.';
  GameStatusTone _statusTone = GameStatusTone.warning;
  String _gestureLabel = '준비 대기';
  String _gestureNote = '시작 자세를 2초 정도 안정적으로 유지하면 baseline을 자동 측정합니다.';
  String _calibrationStage = '준비 대기';
  String _calibrationDetail = '움직임이 적은 시작 자세가 들어오면 자동으로 baseline 측정을 시작합니다.';
  String _calibrationCount = '--';

  double _leftScore = 0;
  double _rightScore = 0;
  double _torsoScore = 0;
  bool _leftRaised = false;
  bool _rightRaised = false;
  bool _bothRaised = false;
  DateTime? _bothRaisedSince;

  int _levelIndex = 0;
  int _score = 0;
  int _lives = 3;
  _GamePhase _phase = _GamePhase.ready;
  _GameControl _control = _GameControl.center;
  final _GamePaddle _paddle = _GamePaddle();
  final _GameBall _ball = _GameBall();
  List<_GameBrick> _bricks = <_GameBrick>[];

  bool get isConnected => _socketState == PiSocketConnectionState.connected;
  bool get esp32Connected => _esp32Connected;
  String get connectionLabel {
    if (_socketState == PiSocketConnectionState.connecting) {
      return '연결 중';
    }
    if (!isConnected) {
      return '오프라인';
    }
    return _esp32Connected ? '온라인' : '대기';
  }

  String get frameStatus => _frameStatus;
  int get displayLevel => _levelIndex + 1;
  int get score => _score;
  int get lives => _lives;
  String get gestureLabel => _gestureLabel;
  String get gestureNote => _gestureNote;
  String get statusMessage => _statusMessage;
  GameStatusTone get statusTone => _statusTone;
  String get calibrationStage => _calibrationStage;
  String get calibrationDetail => _calibrationDetail;
  String get calibrationCount => _calibrationCount;
  double get leftScore => _leftScore;
  double get rightScore => _rightScore;
  double get torsoScore => _torsoScore;
  String get phaseLabel => _phase.name;
  String get controlLabel => _control.name;
  String get ballLabel => _ball.stuck ? 'ready' : 'active';
  bool get showOverlay => !_baselineReady || _phase != _GamePhase.running;

  String get overlayTitle {
    if (!_baselineReady) {
      return '게임 준비';
    }
    return switch (_phase) {
      _GamePhase.ready => '${displayLevel}레벨 준비',
      _GamePhase.levelReady => '${displayLevel}레벨 준비',
      _GamePhase.victory => '클리어',
      _GamePhase.gameOver => '게임 오버',
      _GamePhase.waiting => '연결 대기',
      _GamePhase.running => '',
    };
  }

  String get overlayDescription {
    if (!_baselineReady) {
      return '센서를 부착한 뒤 시작 자세를 약 2초간 안정적으로 유지하면 baseline을 자동 측정합니다.';
    }
    return switch (_phase) {
      _GamePhase.ready => '양팔을 동시에 들어 올리면 공이 발사되고 1레벨이 시작됩니다.',
      _GamePhase.levelReady => '남은 벽돌을 모두 깨면 다음 레벨로 넘어갑니다.',
      _GamePhase.victory => '모든 레벨을 완료했습니다. 양팔을 동시에 들면 1레벨부터 다시 시작합니다.',
      _GamePhase.gameOver => '점수를 유지한 채 종료되었습니다. 양팔을 동시에 들면 다시 시작합니다.',
      _GamePhase.waiting => 'Pi와 ESP32 연결 상태를 확인하고 있습니다.',
      _GamePhase.running => '',
    };
  }

  String get overlayHint {
    if (!_baselineReady) {
      return 'baseline이 끝나면 양팔 동시 들기로 1레벨을 시작할 수 있습니다.';
    }
    return switch (_phase) {
      _GamePhase.ready => '왼팔=왼쪽, 양팔=가운데, 오른팔=오른쪽 패들 활성화',
      _GamePhase.levelReady => '양팔 동시 들기로 다음 레벨 시작',
      _GamePhase.victory => '양팔 동시 들기로 새 게임 시작',
      _GamePhase.gameOver => '양팔 동시 들기로 재도전',
      _GamePhase.waiting => '센서 프레임이 들어오면 자동으로 시작됩니다.',
      _GamePhase.running => '',
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
    _startLoop();
    _connectionSubscription = _piSocketService.connectionState.listen(
      _handleSocketState,
    );
    _connectionStatusSubscription =
        _piSocketService.messagesOf<ConnectionStatusMessage>().listen(
      (message) {
        _esp32Connected = message.esp32Connected;
        if (_esp32Connected) {
          _setStatus('센서 프레임을 수신 중입니다. 시작 자세를 유지해 baseline을 측정하세요.');
        } else {
          _setStatus('ESP32 연결을 기다리는 중입니다.', tone: GameStatusTone.warning);
        }
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

  void _startLoop() {
    _loopTimer = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final now = DateTime.now();
      final last = _lastTickAt;
      _lastTickAt = now;
      final deltaMs = last == null ? 16.0 : now.difference(last).inMilliseconds.toDouble();

      if (_phase == _GamePhase.running) {
        _updateBall(deltaMs);
        _updateBricks();
      } else if (_ball.stuck) {
        _updateBall(deltaMs);
      }
      _safeNotify();
    });
  }

  void _handleSensorFrame(SensorFrameMessage message) {
    if (message.imus.length < 3) {
      return;
    }
    _frameStatus = 'seq ${message.seq} / ts ${message.timestampMs}ms';

    if (!_baselineReady) {
      _captureBaseline(message);
      _safeNotify();
      return;
    }

    _processGesture(message);
    _safeNotify();
  }

  void _captureBaseline(SensorFrameMessage message) {
    final current = _BaselineFrame(
      accels: message.imus.map((imu) => imu.accel).toList(growable: false),
      gyros: message.imus.map((imu) => imu.gyro).toList(growable: false),
    );

    if (_previousFrame == null) {
      _previousFrame = current;
      _gestureLabel = '준비 자세 확인';
      _gestureNote = '시작 자세를 안정적으로 유지하면 baseline 측정을 시작합니다.';
      _calibrationStage = '준비 대기';
      _calibrationDetail = '움직임이 적은 시작 자세가 들어오면 자동으로 baseline 측정을 시작합니다.';
      _calibrationCount = '--';
      _setStatus('센서 입력을 확인 중입니다. 시작 자세를 유지하세요.', tone: GameStatusTone.warning);
      return;
    }

    final armAccelDrift =
        _vectorDeltaNorm(current.accels[0], _previousFrame!.accels[0]) +
        _vectorDeltaNorm(current.accels[1], _previousFrame!.accels[1]);
    final torsoAccelDrift =
        _vectorDeltaNorm(current.accels[2], _previousFrame!.accels[2]);
    final armGyroDrift =
        _vectorDeltaNorm(current.gyros[0], _previousFrame!.gyros[0]) +
        _vectorDeltaNorm(current.gyros[1], _previousFrame!.gyros[1]);
    final torsoGyroDrift =
        _vectorDeltaNorm(current.gyros[2], _previousFrame!.gyros[2]);

    final stableNow =
        armAccelDrift + torsoAccelDrift <= 0.09 &&
        armGyroDrift + torsoGyroDrift <= 1.35;

    _previousFrame = current;

    if (!stableNow) {
      _stableCount = 0;
      _baselineFrames.clear();
      _gestureLabel = '자세 조정';
      _gestureNote = '움직임이 감지되었습니다. 팔을 내린 시작 자세를 다시 유지하세요.';
      _calibrationStage = '자세 조정';
      _calibrationDetail = '움직임이 감지되었습니다. 팔을 내리고 다시 안정적으로 자세를 맞춰주세요.';
      _calibrationCount = '--';
      _setStatus(
        '캘리브레이션 중 자세가 흔들리고 있습니다. 잠시 가만히 있어주세요.',
        tone: GameStatusTone.warning,
      );
      return;
    }

    _stableCount += 1;
    if (_stableCount < 45) {
      _gestureLabel = '안정화 중';
      _gestureNote = '시작 자세 유지 $_stableCount/45';
      _calibrationStage = '안정화 중';
      _calibrationDetail = '시작 자세를 유지하면 baseline 측정 준비를 진행합니다.';
      _calibrationCount = '${math.max(1, ((45 - _stableCount) / 20).ceil())}';
      _setStatus('시작 자세가 안정적인지 확인하는 중입니다.', tone: GameStatusTone.warning);
      return;
    }

    _baselineFrames.add(current);
    if (_baselineFrames.length < 60) {
      _gestureLabel = '측정 중';
      _gestureNote = '시작 자세를 유지하세요 baseline ${_baselineFrames.length}/60';
      _calibrationStage = '측정 중';
      _calibrationDetail = '기준 자세 baseline을 수집하는 중입니다. 계속 가만히 유지해주세요.';
      _calibrationCount = '${math.max(1, ((60 - _baselineFrames.length) / 20).ceil())}';
      _setStatus('게임 입력 기준값을 수집 중입니다.', tone: GameStatusTone.warning);
      return;
    }

    _baselineAccels = _meanFrames(_baselineFrames, (frame) => frame.accels);
    _baselineGyros = _meanFrames(_baselineFrames, (frame) => frame.gyros);
    _baselineReady = true;
    _baselineFrames.clear();
    _stableCount = 45;
    _gestureLabel = '준비 완료';
    _gestureNote = '양팔을 동시에 들어 올리면 게임이 시작됩니다.';
    _calibrationStage = '측정 완료';
    _calibrationDetail = 'baseline 캘리브레이션이 끝났습니다. 양팔 동시 들기로 레벨을 시작하세요.';
    _calibrationCount = 'OK';
    _setStatus('baseline 측정 완료. 양팔 들어 올리기 제스처를 기다립니다.', tone: GameStatusTone.success);
  }

  void _processGesture(SensorFrameMessage message) {
    final accel0 = message.imus[0].accel;
    final accel1 = message.imus[1].accel;
    final accel2 = message.imus[2].accel;
    final gyro0 = message.imus[0].gyro;
    final gyro1 = message.imus[1].gyro;
    final gyro2 = message.imus[2].gyro;

    _leftScore = _vectorDeltaNorm(accel0, _baselineAccels![0]) +
        _vectorDeltaNorm(gyro0, _baselineGyros![0]) * 0.08;
    _rightScore = _vectorDeltaNorm(accel1, _baselineAccels![1]) +
        _vectorDeltaNorm(gyro1, _baselineGyros![1]) * 0.08;
    _torsoScore = _vectorDeltaNorm(accel2, _baselineAccels![2]) +
        _vectorDeltaNorm(gyro2, _baselineGyros![2]) * 0.05;

    _leftRaised = _leftScore >= 0.78;
    _rightRaised = _rightScore >= 0.78;
    _bothRaised = _leftRaised && _rightRaised && _torsoScore < 0.95;

    if (_leftRaised && _rightRaised) {
      _control = _GameControl.center;
      _paddle.activeIndex = 1;
    } else if (_leftRaised && !_rightRaised) {
      _control = _GameControl.left;
      _paddle.activeIndex = 0;
    } else if (_rightRaised && !_leftRaised) {
      _control = _GameControl.right;
      _paddle.activeIndex = 2;
    } else {
      _control = _GameControl.neutral;
    }

    final now = DateTime.now();
    if (_bothRaised) {
      _bothRaisedSince ??= now;
      final heldMs = now.difference(_bothRaisedSince!).inMilliseconds;
      _gestureLabel = '인식 중';
      _gestureNote = '양팔 들기 유지 ${math.min(600, heldMs)}ms';
      if (heldMs >= 420) {
        if (_phase == _GamePhase.ready || _phase == _GamePhase.levelReady) {
          _startLevel();
        } else if (_phase == _GamePhase.victory || _phase == _GamePhase.gameOver) {
          _restartGame();
        }
        _bothRaisedSince = null;
      }
      return;
    }

    _bothRaisedSince = null;
    _gestureLabel = '준비 완료';
    _gestureNote = '왼팔=왼쪽, 양팔=가운데, 오른팔=오른쪽 패들';
  }

  void _loadLevel(int index) {
    _levelIndex = index;
    _bricks = _buildBricks(_levels[index]);
    _updatePaddleLayout();
    _paddle.activeIndex = 1;
    _control = _GameControl.center;
    _resetBall(stuck: true);
    _phase = index == 0 ? _GamePhase.ready : _GamePhase.levelReady;
    _gestureLabel = '시작 대기';
    _gestureNote = '양팔을 동시에 들어 올리면 ${index + 1}레벨이 시작됩니다.';
    _setStatus('양팔 들기 시작 제스처를 기다리는 중입니다.', tone: GameStatusTone.warning);
  }

  List<_GameBrick> _buildBricks(_GameLevelConfig config) {
    const top = 90.0;
    const side = 54.0;
    const gap = 10.0;
    const brickHeight = 24.0;
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

  void _updatePaddleLayout() {
    _paddle.width = math.min(boardWidth - 36, boardWidth * 0.94);
    _paddle.height = 28;
    _paddle.x = (boardWidth - _paddle.width) / 2;
    _paddle.y = boardHeight - 48;
  }

  void _resetBall({required bool stuck}) {
    final segmentWidth = _paddle.width / 3;
    _ball.radius = 10;
    _ball.x = _paddle.x + segmentWidth * (_paddle.activeIndex + 0.5);
    _ball.y = _paddle.y - _ball.radius - 4;
    _ball.vx = 0;
    _ball.vy = 0;
    _ball.stuck = stuck;
  }

  void _startLevel() {
    final speed = _levels[_levelIndex].ballSpeed;
    _ball.vx = speed * 0.7;
    _ball.vy = -speed;
    _ball.stuck = false;
    _paddle.activeIndex = 1;
    _control = _GameControl.center;
    _phase = _GamePhase.running;
    _setStatus('게임 진행 중입니다.', tone: GameStatusTone.normal);
  }

  void _restartGame() {
    _score = 0;
    _lives = 3;
    _loadLevel(0);
  }

  void _startNextLevelOrWin() {
    if (_levelIndex + 1 >= _levels.length) {
      _phase = _GamePhase.victory;
      _gestureLabel = '다시 시작 가능';
      _gestureNote = '양팔 동시 들기로 1레벨부터 다시 시작합니다.';
      _setStatus('모든 레벨을 완료했습니다.', tone: GameStatusTone.success);
      return;
    }
    _loadLevel(_levelIndex + 1);
  }

  void _loseLife() {
    _lives = math.max(0, _lives - 1);
    if (_lives <= 0) {
      _phase = _GamePhase.gameOver;
      _gestureLabel = '다시 시작 가능';
      _gestureNote = '양팔 동시 들기로 다시 시작합니다.';
      _setStatus('공을 놓쳤습니다. 게임 오버입니다.', tone: GameStatusTone.danger);
      return;
    }

    _phase = _GamePhase.ready;
    _resetBall(stuck: true);
    _gestureLabel = '다시 시작 가능';
    _gestureNote = '양팔 동시 들기로 공을 다시 발사합니다.';
    _setStatus('공이 바닥으로 떨어졌습니다. 다시 시작 제스처를 기다립니다.', tone: GameStatusTone.warning);
  }

  void _updateBall(double deltaMs) {
    if (_ball.stuck) {
      final segmentWidth = _paddle.width / 3;
      _ball.x = _paddle.x + segmentWidth * (_paddle.activeIndex + 0.5);
      _ball.y = _paddle.y - _ball.radius - 4;
      return;
    }

    final moveScale = deltaMs * 0.06;
    _ball.x += _ball.vx * moveScale;
    _ball.y += _ball.vy * moveScale;

    if (_ball.x <= 28 || _ball.x >= boardWidth - 28) {
      _ball.vx *= -1;
      _ball.x = _clamp(_ball.x, 28, boardWidth - 28);
    }

    if (_ball.y <= 34) {
      _ball.vy *= -1;
      _ball.y = 34;
    }

    if (_ball.y + _ball.radius >= _paddle.y &&
        _ball.y - _ball.radius <= _paddle.y + _paddle.height &&
        _ball.x >= _paddle.x &&
        _ball.x <= _paddle.x + _paddle.width &&
        _ball.vy > 0) {
      final segmentWidth = _paddle.width / 3;
      final segmentIndex = _clampInt(
        ((_ball.x - _paddle.x) / segmentWidth).floor(),
        0,
        2,
      );

      if (segmentIndex == _paddle.activeIndex) {
        final segmentCenter = _paddle.x + segmentWidth * (segmentIndex + 0.5);
        final localRatio = (_ball.x - segmentCenter) / (segmentWidth / 2);
        _ball.vx = _clamp(localRatio * 5.8 + (segmentIndex - 1) * 1.6, -7.2, 7.2);
        _ball.vy = -_ball.vy.abs();
        _setStatus('활성 패들로 공을 받아냈습니다.');
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
      _startNextLevelOrWin();
    }
  }

  double _vectorDeltaNorm(List<double> current, List<double> baseline) {
    return (current[0] - baseline[0]).abs() +
        (current[1] - baseline[1]).abs() +
        (current[2] - baseline[2]).abs();
  }

  List<List<double>> _meanFrames(
    List<_BaselineFrame> frames,
    List<List<double>> Function(_BaselineFrame frame) extractor,
  ) {
    final sums = List<List<double>>.generate(
      3,
      (_) => List<double>.filled(3, 0),
      growable: false,
    );
    for (final frame in frames) {
      final values = extractor(frame);
      for (var i = 0; i < 3; i++) {
        for (var axis = 0; axis < 3; axis++) {
          sums[i][axis] += values[i][axis];
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

  double _clamp(double value, double min, double max) {
    return math.max(min, math.min(max, value));
  }

  int _clampInt(int value, int min, int max) {
    return math.max(min, math.min(max, value));
  }

  void _setStatus(String message, {GameStatusTone tone = GameStatusTone.normal}) {
    _statusMessage = message;
    _statusTone = tone;
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
    _sensorSubscription?.cancel();
    _connectionStatusSubscription?.cancel();
    _loopTimer?.cancel();
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

enum _GamePhase { waiting, ready, levelReady, running, victory, gameOver }

enum _GameControl { neutral, left, center, right }

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
  double radius = 10;
  bool stuck = true;
}

class _BaselineFrame {
  const _BaselineFrame({
    required this.accels,
    required this.gyros,
  });

  final List<List<double>> accels;
  final List<List<double>> gyros;
}
