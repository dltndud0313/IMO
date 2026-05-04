import 'dart:io';

Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.anyIPv4, 8765);
  print('Mock Pi WebSocket server listening on ws://0.0.0.0:8765');
  print('Android emulator URL: ws://10.0.2.2:8765');

  await for (final request in server) {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      continue;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    print('App connected');
    socket.listen(
      (data) {
        print('APP -> PI $data');
        if (data is! String) {
          return;
        }
        if (data.contains('"type":"submit_workout_plan"')) {
          socket.add(
            '{"type":"plan_ack","payload":{"accepted":true,"exercise_type":"pushup","set_count":3}}',
          );
        }
        if (data.contains('"type":"start_calibration"')) {
          socket.add(
            '{"type":"calibration_status","payload":{"status":"started","message":"Mock calibration started"}}',
          );
          Future<void>.delayed(const Duration(seconds: 2), () {
            socket.add(
              '{"type":"calibration_status","payload":{"status":"success","message":"Mock calibration success"}}',
            );
          });
        }
      },
      onDone: () => print('App disconnected'),
      onError: (Object error) => print('Socket error: $error'),
    );
  }
}
