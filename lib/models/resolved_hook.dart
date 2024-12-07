import 'package:equatable/equatable.dart';
import 'package:hooksman/models/resolved_hook_task.dart';

part 'resolved_hook.g.dart';

class ResolvedHook extends Equatable {
  ResolvedHook({
    required this.files,
    required this.tasks,
  }) {
    final allTasks =
        tasks.expand((task) => [task].followedBy(task.subTasks)).toList();

    tasksById = {
      for (final task in allTasks) task.original.id: task,
    };
  }

  final List<String> files;
  final List<ResolvedHookTask> tasks;

  late final Map<String, ResolvedHookTask> tasksById;

  @override
  List<Object?> get props => _$props;
}
