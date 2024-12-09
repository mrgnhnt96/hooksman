import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:meta/meta.dart';

abstract class SequentialTask extends HookTask {
  SequentialTask({
    required super.include,
    super.exclude,
  });

  @override
  String get name;

  @nonVirtual
  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  }) async {
    for (final task in subTasks(files)) {
      startTask(task);
      final result = await task.run(
        files,
        print: print,
        completeTask: completeTask,
        startTask: startTask,
      );

      completeTask(task, result);
      if (result != 0) return result;
    }

    completeTask(this, 0);

    return 0;
  }
}
