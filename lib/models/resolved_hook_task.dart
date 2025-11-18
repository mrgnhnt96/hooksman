import 'package:hooksman/models/task_label.dart';
import 'package:hooksman/tasks/hook_task.dart';

class ResolvedHookTask {
  const ResolvedHookTask({
    required this.files,
    required this.workingDirectory,
    required this.original,
    required this.index,
    required this.label,
    required this.subTasks,
    required this.always,
  });

  final List<String> files;
  final HookTask original;
  final int index;
  final TaskLabel label;
  final bool always;
  final List<ResolvedHookTask> subTasks;
  final String? workingDirectory;

  bool get hasChildren => subTasks.isNotEmpty;
  bool get hasFiles => files.isNotEmpty;
  int get fileCount => files.length;

  String get name => label.name;
}
