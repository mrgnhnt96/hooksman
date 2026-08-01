part of '../running.dart';

class _SubTasks extends StatelessComponent {
  const _SubTasks(this.subTasks, {required this.indent});

  final List<PendingTask> subTasks;
  final int indent;

  @override
  Component build(BuildContext context) {
    if (subTasks.isEmpty) {
      return const SizedBox();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final task in subTasks) Running._nested(task, indent + 1),
      ],
    );
  }
}
