import 'dart:async';

import 'package:nocterm/nocterm.dart';

class InitialStep extends StatefulComponent {
  const InitialStep({super.key});

  @override
  State<InitialStep> createState() => _InitialStepState();
}

class _InitialStepState extends State<InitialStep> {
  late final Timer _timer;

  static const _frames = ['⠋', '⠙', '⠹', '⠸', '⠼', '⠴', '⠦', '⠧', '⠇', '⠏'];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final frame = _frames[_timer.tick % _frames.length];

    return Row(
      children: [
        Text(frame, style: const TextStyle(color: Colors.yellow)),
        const SizedBox(width: 1),
        const Text('Preparing…', style: TextStyle(color: Colors.grey)),
      ],
    );
  }
}
