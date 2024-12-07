import 'dart:async';

import 'package:hooksman/hooksman.dart';

abstract class SequentialTask extends HookTask {
  SequentialTask({
    required super.include,
    super.exclude,
  });

  @override
  String get name;

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask) completeTask,
  }) async {
    for (final task in subTasks(files)) {
      final result = await task.run(
        files,
        print: print,
        completeTask: completeTask,
      );

      completeTask(task);
      if (result != 0) return result;
    }

    completeTask(this);

    return 0;
  }
}
