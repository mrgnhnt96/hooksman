import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:meta/meta.dart';

class ParallelTasks extends HookTask {
  ParallelTasks({
    required super.include,
    required List<HookTask> tasks,
    super.exclude,
    this.name,
  }) : _tasks = tasks;

  @override
  final String? name;

  final List<HookTask> _tasks;

  @override
  List<HookTask> getSubTasks(Iterable<String> filePaths) => _tasks;

  @nonVirtual
  @override
  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  }) async {
    final futures = <Future<int>>[];

    for (final task in subTasks(filePaths)) {
      startTask(task);
      Future<int> value() async {
        return await task.run(
          filePaths,
          print: print,
          completeTask: completeTask,
          startTask: startTask,
        );
      }

      futures.add(
        value().then((code) {
          completeTask(task, code);

          if (code != 0) {
            // ignore: only_throw_errors
            throw code;
          }

          return code;
        }),
      );
    }

    try {
      await Future.wait(futures);
    } on int catch (code) {
      return code;
    }

    completeTask(this, 0);

    return 0;
  }
}
