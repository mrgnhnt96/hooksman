part of '../running.dart';

class _ProgressIndicator extends StatefulComponent {
  const _ProgressIndicator();

  @override
  State<StatefulComponent> createState() => _ProgressIndicatorState();
}

class _ProgressIndicatorState extends State<_ProgressIndicator> {
  late final Timer _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  static const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  @override
  Component build(BuildContext context) {
    final tick = _timer.tick;

    final frame = _frames[tick % _frames.length];

    return Text(frame, style: const TextStyle(color: Colors.yellow));
  }
}
