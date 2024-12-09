import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:mason_logger/mason_logger.dart';

class TaskRunner {
  const TaskRunner({
    required this.logger,
    required this.task,
    required this.completeTask,
    required this.startTask,
  });

  final Logger logger;
  final PendingTask task;
  final void Function(HookTask, int) completeTask;
  final void Function(HookTask) startTask;

  Future<int> run() async {
    final task = this.task;

    if (task.files.isEmpty) {
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
