import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:mason_logger/mason_logger.dart';

class TaskRunner {
  const TaskRunner({
    required this.logger,
    required this.task,
    required this.completeTask,
  });

  final Logger logger;
  final PendingTask task;
  final void Function(HookTask) completeTask;

  Future<int> run() async {
    final task = this.task;

    if (task.files.isEmpty) {
      return 0;
    }

    try {
      return await runZoned(
        () async {
          return await task.run(
            task.files.toList(),
            print: logger.delayed,
            completeTask: completeTask,
          );
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            // don't print anything
          },
        ),
      );
    } catch (e) {
      logger
        ..delayed(red.wrap('Error when running ${task.name}'))
        ..delayed('$e');

      completeTask(task.resolvedTask.original);

      return 1;
    }
  }
}
