import 'package:hooksman/tasks/hook_task.dart';
import 'package:hooksman/tasks/sequential_task.dart';
import 'package:hooksman/utils/all_files.dart';

class SequentialTasks extends SequentialTask {
  SequentialTasks({
    required List<HookTask> tasks,
    this.name,
    List<Pattern>? include,
    super.exclude,
  })  : _tasks = tasks,
        super(include: include ?? [AllFiles()]);

  @override
  final String? name;

  final List<HookTask> _tasks;

  @override
  List<HookTask> getSubTasks(Iterable<String> files) => _tasks;
}
