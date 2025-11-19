import 'package:equatable/equatable.dart';
import 'package:hooksman/models/resolved_hook_task.dart';

part 'resolved_hook.g.dart';

class ResolvedHook extends Equatable {
  ResolvedHook({
    required this.filePaths,
    required this.tasks,
    required this.runInParallel,
  }) {
    Iterable<ResolvedHookTask> subTasks(ResolvedHookTask task) sync* {
      for (final subTask in task.subTasks) {
        yield subTask;
        yield* subTasks(subTask);
      }
    }

    final allTasks = [
      for (final task in tasks) ...[task, ...subTasks(task)],
    ];

    tasksById = {for (final task in allTasks) task.original.id: task};
  }

  final List<String> filePaths;
  final List<ResolvedHookTask> tasks;
  final bool runInParallel;
  late final Map<String, ResolvedHookTask> tasksById;

  @override
  List<Object?> get props => _$props;
}
