import 'dart:async';
import 'dart:io' as io;
import 'dart:io';

class MultiLineProgress {
  MultiLineProgress({
    required String Function(String) createLabel,
  }) : this._(
          stdout,
          createLabel: createLabel,
        );

  MultiLineProgress._(
    this._stdout, {
    required this.createLabel,
  });

  final io.Stdout _stdout;
  final String Function(String) createLabel;
  Timer? _timer;

  static const _frames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏',
  ];

  int _index = 0;
  void _onTick(Timer? _) {
    _clear();
    final frame = _frames[_index % _frames.length];

    _stdout.write(createLabel(frame));
    _index++;
  }

  void _clear() {
    _stdout.write('\x1B[2J\x1B[H');
  }

  bool _running = false;

  void start() {
    if (_running) {
      return;
    }

    // clear terminal
    _clear();
    _timer = Timer.periodic(const Duration(milliseconds: 80), _onTick);
    _running = true;
  }

  void dispose() {
    _timer?.cancel();
    _running = false;
  }

  void print() {
    _clear();
    _stdout.writeln(createLabel(''));
  }

  Future<void> closeNextFrame() async {
    await Future<void>.delayed(const Duration(milliseconds: 80));

    dispose();
  }
}
