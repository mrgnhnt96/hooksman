import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/task_label.dart';

class ResolvedHookTask {
  const ResolvedHookTask({
    required this.files,
    required this.original,
    required this.index,
    required this.label,
  });

  final List<String> files;
  final HookTask original;
  final int index;
  final TaskLabel label;
}
