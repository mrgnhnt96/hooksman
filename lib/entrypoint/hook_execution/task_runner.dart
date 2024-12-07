import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:mason_logger/mason_logger.dart';

class TaskRunner {
  const TaskRunner({
    required this.taskId,
    required this.logger,
    required this.task,
    required this.files,
    required this.completeSubTask,
  });

  final String taskId;
  final Logger logger;
  final ResolvingTask task;
  final List<String> files;
  final void Function(int) completeSubTask;

  Future<int> run() async {
    if (files.isEmpty) {
      return 0;
    }

    final task = this.task;
    final result = await task.run(
      files,
      print: logger.delayed,
      completeSubTask: completeSubTask,
    );

    return result;
  }

  Future<int> runDart(DartTask task) async {
    try {
      return await runZoned(
        () async {
          return await task.run(
            files,
            print: logger.delayed,
            completeSubTask: completeSubTask,
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
        ..delayed(red.wrap('Error when running ${task.resolvedName}'))
        ..delayed('$e');

      return 1;
    }
  }
}
