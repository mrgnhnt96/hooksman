import 'dart:async';

import 'package:hooksman/models/pending_task.dart';
import 'package:hooksman/tasks/hook_task.dart';
import 'package:mason_logger/mason_logger.dart';

class TaskRunner {
  TaskRunner({
    required this.logger,
    required this.task,
    required this.completeTask,
    required this.startTask,
  }) {
    if (!task.wasSkipped) return;

    // task has no files and is not set to always run
    // so we need to start and complete it manually
    startTask(task.resolvedTask.original);
    completeTask(task.resolvedTask.original, 0);
  }

  final Logger logger;
  final PendingTask task;
  final void Function(HookTask, int) completeTask;
  final void Function(HookTask) startTask;

  Future<int> run() async {
    final task = this.task;

    if (task.wasSkipped) {
      return 0;
    }

    try {
      return await runZoned(
        () async {
          final result = await task.run(
            task.files.toList(),
            print: logger.delayed,
            completeTask: completeTask,
            startTask: startTask,
          );

          completeTask(task.resolvedTask.original, result);
          return result;
        },
        zoneSpecification: ZoneSpecification(
          print: (self, parent, zone, line) {
            logger.delayed(line);
          },
        ),
      );
    } catch (e) {
      logger
        ..delayed(red.wrap('Error when running ${task.name}'))
        ..delayed('$e');

      completeTask(task.resolvedTask.original, 1);

      return 1;
    }
  }
}
