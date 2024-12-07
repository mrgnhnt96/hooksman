import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:hooksman/models/task_label.dart';

class SequentialTasks extends HookTask {
  SequentialTasks({
    required String super.name,
    required this.tasks,
    List<Pattern>? include,
  }) : super(include: include ?? [AllFiles()]);

  final List<HookTask> tasks;

  @override
  TaskLabel label(Iterable<String> files) {
    return TaskLabel(
      resolvedName,
      fileCount: files.length,
      children: tasks.map((e) {
        return e.label(files);
      }).toList(),
    );
  }

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(int) completeSubTask,
  }) async {
    var index = 0;
    for (final task in tasks) {
      final result = await task.run(
        files,
        print: print,
        completeSubTask: completeSubTask,
      );

      if (result != 0) return result;
      index = task.label(files).length;
      completeSubTask(index);
    }

    completeSubTask(0);

    return 0;
  }
}

// should come back
