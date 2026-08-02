import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class LogService {
  static final LogService _instance = LogService._internal();
  factory LogService() => _instance;
  LogService._internal();

  static const int _maxBuffer = 200;
  static const int _maxFileSize = 5 * 1024 * 1024;

  final List<String> _buffer = [];
  String _currentDate = '';
  String? _logsDir;
  bool _ready = false;
  File? _logFile;

  Future<void> init() async {
    if (_ready) return;
    try {
      final appDir = await getApplicationDocumentsDirectory();
      _logsDir = p.join(appDir.path, 'alshami_logs');
      await Directory(_logsDir!).create(recursive: true);
      _rotateLog();
      _ready = true;
    } catch (_) {}
  }

  void _rotateLog() {
    final dir = _logsDir;
    if (dir == null) return;
    final d = _today();
    _currentDate = d;
    final path = p.join(dir, 'alshami_$d.log');
    final f = File(path);
    if (f.existsSync() && f.lengthSync() > _maxFileSize) {
      f.renameSync(p.join(dir, 'alshami_${d}_old.log'));
    }
    _logFile = File(path);
  }

  String _today() {
    final n = DateTime.now();
    return '${n.year}-${_pad(n.month)}-${_pad(n.day)}';
  }

  String _pad(int v) => v.toString().padLeft(2, '0');

  String _timestamp() {
    final n = DateTime.now();
    return '${n.year}-${_pad(n.month)}-${_pad(n.day)} ${_pad(n.hour)}:${_pad(n.minute)}:${_pad(n.second)}.${n.millisecond.toString().padLeft(3, '0')}';
  }

  void _write(String lvl, String msg) {
    final ts = _timestamp();
    final line = '[$ts] [$lvl] $msg';
    _buffer.add(line);
    if (_buffer.length > _maxBuffer) _buffer.removeAt(0);
    debugPrint(line);
    if (_ready && _logFile != null) {
      try {
        final d = _today();
        if (d != _currentDate) _rotateLog();
        _logFile!.writeAsStringSync('$line\n', mode: FileMode.append, flush: true);
      } catch (_) {}
    }
  }

  static void d(String m) => _instance._write('DEBUG', m);
  static void i(String m) => _instance._write('INFO', m);
  static void w(String m) => _instance._write('WARN', m);
  static void e(String m) => _instance._write('ERROR', m);

  List<String> getBuffer() => List.unmodifiable(_buffer);

  String? getTodayLogPath() {
    if (_logFile != null && _logFile!.existsSync()) return _logFile!.path;
    return null;
  }
}
