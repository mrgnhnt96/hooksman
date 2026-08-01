part of '../running.dart';

class _PendingTask {
  const _PendingTask._({
    required this.status,
    required this.fileCount,
    required this.index,
    required this.name,
    required this.hasSubtasks,
    required this.subTasks,
    required this.hasCompleted,
    required this.hasHalted,
    required this.indent,
  });

  factory _PendingTask.snapshot(PendingTask task, {required int indent}) {
    return _PendingTask._(
      status: _statusFor(task),
      fileCount: task.resolvedTask.fileCount,
      index: task.resolvedTask.index,
      name: task.resolvedTask.name,
      hasSubtasks: task.resolvedTask.subTasks.isNotEmpty,
      subTasks: task.subTasks,
      hasCompleted: task.hasCompleted,
      hasHalted: task.isHalted,
      indent: indent,
    );
  }

  final _TaskStatus status;
  final int fileCount;
  final int index;
  final String name;
  final bool hasSubtasks;
  final List<PendingTask> subTasks;
  final bool hasCompleted;
  final bool hasHalted;
  final int indent;

  static _TaskStatus _statusFor(PendingTask task) {
    return switch (task) {
      _ when task.isError => _TaskStatus.error,
      _ when task.hasCompleted => _TaskStatus.completed,
      _ when task.isHalted => _TaskStatus.halted,
      _ when task.wasSkipped => _TaskStatus.skipped,
      _ when task.isRunning => _TaskStatus.running,
      _ when task.hasStarted => _TaskStatus.started,
      _ when !task.hasStarted => _TaskStatus.pending,
      _ => _TaskStatus.unknown,
    };
  }
}

enum _TaskStatus {
  pending,
  running,
  completed,
  error,
  started,
  skipped,
  halted,
  unknown,
}
