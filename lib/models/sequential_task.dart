import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:hooksman/models/task_label.dart';

abstract class SequentialTask extends HookTask {
  SequentialTask({
    required super.include,
    super.exclude,
  });

  @override
  String get name;
  List<HookTask> tasks(Iterable<String> files);

  @override
  TaskLabel label(Iterable<String> files) {
    return TaskLabel(
      resolvedName,
      taskId: id,
      fileCount: files.length,
      children: tasks(files).map((e) {
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
    for (final task in tasks(files)) {
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
