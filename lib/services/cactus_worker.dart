import 'dart:async';
import 'dart:isolate';
import 'dart:ffi';
import 'cactus_ffi.dart' as cactus;

class CactusWorker {
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  Isolate? _isolate;

  bool get isRunning => _isolate != null;

  Future<void> start() async {
    if (isRunning) return;
    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_entry, _receivePort!.sendPort);
    _sendPort = await _receivePort!.first as SendPort;
  }

  Future<String> init(String modelPath) async {
    return _send('init', modelPath);
  }

  Future<String> generate(String messagesJson, String? optionsJson) async {
    return _send('generate', messagesJson, optionsJson ?? '');
  }

  Future<void> dispose() async {
    if (_sendPort != null) {
      try {
        final rp = ReceivePort();
        _sendPort!.send(['destroy', '', '', rp.sendPort]);
        await rp.first.timeout(const Duration(seconds: 5));
        rp.close();
      } catch (_) {}
    }
    _isolate?.kill();
    _receivePort?.close();
    _sendPort = null;
    _isolate = null;
  }

  Future<String> _send(String type, String a1, [String a2 = '']) async {
    if (!isRunning) return 'error:Worker not started';
    final rp = ReceivePort();
    _sendPort!.send([type, a1, a2, rp.sendPort]);
    final result = await rp.first;
    rp.close();
    return result as String;
  }

  static void _entry(SendPort main) {
    final port = ReceivePort();
    main.send(port.sendPort);
    Pointer<Void>? model;

    port.listen((msg) {
      final args = msg as List<dynamic>;
      final cmd = args[0] as String;
      final a1 = args[1] as String;
      final a2 = args[2] as String;
      final reply = args[3] as SendPort;

      try {
        if (cmd == 'init') {
          model = cactus.init(a1, null, false);
          reply.send('ok');
        } else if (cmd == 'generate') {
          if (model == null) { reply.send('error:No model'); return; }
          final result = cactus.complete(model!, a1, a2.isEmpty ? null : a2);
          reply.send(result);
        } else if (cmd == 'destroy') {
          if (model != null) cactus.destroy(model!);
          reply.send('ok');
          port.close();
        }
      } catch (e) {
        reply.send('error:$e');
      }
    });
  }
}
