part of '../running.dart';

class _Icon extends StatelessComponent {
  const _Icon({required this.status, required this.hasSubtasks});

  final _TaskStatus status;
  final bool hasSubtasks;

  static const down = '↓';
  static const right = '→';
  static const dot = '•';
  static const checkMark = '✓';
  static const x = 'ⅹ';
  static const warning = '⚠️';
  static const waiting = '-';

  @override
  Component build(BuildContext context) {
    if (status == _TaskStatus.running) {
      return const _ProgressIndicator();
    }

    final color = switch (status) {
      _TaskStatus.error => Colors.red,
      _TaskStatus.completed => Colors.green,
      _TaskStatus.halted => Colors.blue,
      _TaskStatus.skipped => Colors.yellow,
      _ when hasSubtasks => Colors.yellow,
      _TaskStatus.running => Colors.yellow,
      _TaskStatus.pending => Colors.magenta,
      _TaskStatus.started => Colors.yellow,
      _TaskStatus.unknown => Colors.red,
    };

    final icon = switch (status) {
      _TaskStatus.error => x,
      _TaskStatus.completed => checkMark,
      _TaskStatus.halted => dot,
      _TaskStatus.skipped => down,
      _ when hasSubtasks => right,
      _TaskStatus.running => '',
      _TaskStatus.pending => waiting,
      _TaskStatus.started => waiting,
      _TaskStatus.unknown => warning,
    };

    return Text(icon, style: TextStyle(color: color));
  }
}
