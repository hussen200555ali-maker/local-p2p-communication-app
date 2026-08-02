import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TCP Zombie Socket Diagnostic', () {
    late ServerSocket server;
    late Socket client;
    late int port;

    setUp(() async {
      server = await ServerSocket.bind('127.0.0.1', 0);
      port = server.port;
      server.listen((socket) {
        socket.destroy();
      });
      client = await Socket.connect('127.0.0.1', port);
    });

    tearDown(() async {
      await client.close().catchError((_) {});
      await server.close().catchError((_) {});
    });

    test('[A1] socket.write() succeeds after remote closes', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      try {
        client.write('TEST_MESSAGE_1\n');
      } catch (e) {
        fail('socket.write() threw on what should be a dead socket: $e');
      }
    });

    test('[A2] multiple writes succeed on dead socket', () async {
      await Future.delayed(const Duration(milliseconds: 200));

      for (int i = 0; i < 5; i++) {
        try {
          client.write('MESSAGE_$i\n');
        } catch (e) {
          fail('Write $i failed on dead socket: $e');
        }
      }
    });

    test('[A3] try-catch on write does NOT detect dead connection', () async {
      await Future.delayed(const Duration(milliseconds: 100));

      bool writeReturnedTrue = false;
      try {
        client.write('SILENT_LOSS\n');
        writeReturnedTrue = true;
      } catch (_) {}

      expect(writeReturnedTrue, isTrue,
          reason: 'socket.write() returned without error on a dead connection — this proves try-catch is insufficient');
    });
  });
}
