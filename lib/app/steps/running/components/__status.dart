part of '../running.dart';

class _Status extends StatelessComponent {
  const _Status(this.status) : short = false, hasSubtasks = false;
  const _Status.short(this.status, {required this.hasSubtasks}) : short = true;

  final _TaskStatus status;
  final bool short;
  final bool hasSubtasks;

  @override
  Component build(BuildContext context) {
    final text = switch (short) {
      true => switch (status) {
        _ when hasSubtasks => '-',
        _TaskStatus.running => 'R',
        _TaskStatus.halted => 'H',
        _TaskStatus.error => 'E',
        _TaskStatus.completed => 'C',
        _TaskStatus.skipped => 'S',
        _TaskStatus.pending => 'P',
        _TaskStatus.started => 'P',
        _TaskStatus.unknown => '?',
      },
      false => switch (status) {
        _TaskStatus.pending => 'Pending',
        _TaskStatus.running => 'Running',
        _TaskStatus.completed => 'Completed',
        _TaskStatus.error => 'Error',
        _TaskStatus.started => 'Started',
        _TaskStatus.skipped => 'Skipped',
        _TaskStatus.halted => 'Halted',
        _TaskStatus.unknown => '???',
      },
    };

    return Text(text, style: const TextStyle(color: Colors.grey));
  }
}
