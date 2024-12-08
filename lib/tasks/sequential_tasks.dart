import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/sequential_task.dart';
import 'package:hooksman/utils/all_files.dart';

class SequentialTasks extends SequentialTask {
  SequentialTasks({
    required this.name,
    required List<HookTask> tasks,
    List<Pattern>? include,
    super.exclude,
  })  : _tasks = tasks,
        super(include: include ?? [AllFiles()]);

  @override
  final String name;

  final List<HookTask> _tasks;

  @override
  List<HookTask> getSubTasks(Iterable<String> files) => _tasks;
}
