import 'dart:async';
import 'dart:io';

import 'package:git_hooks/models/dart_script.dart';
import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/models/shell_script.dart';
import 'package:mason_logger/mason_logger.dart';

class TaskRunner {
  const TaskRunner({
    required this.taskId,
    required this.logger,
    required this.task,
    required this.files,
    required this.onSubTaskCompleted,
  });

  final String taskId;
  final Logger logger;
  final HookCommand task;
  final List<String> files;
  final void Function(int)? onSubTaskCompleted;

  Future<int> run() async {
    if (files.isEmpty) {
      return 0;
    }

    final task = this.task;
    final result = await switch (task) {
      DartScript() => runDart(task),
      ShellScript() => runShell(task),
      _ => Future.value(1),
    };

    return result;
  }

  Future<int> runDart(DartScript task) async {
    try {
      return await runZoned(
        () async {
          return await task.script(files);
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

  Future<int> runShell(ShellScript task) async {
    for (final (index, command) in task.commands(files).indexed) {
      final result = await Process.run(
        'bash',
        [
          '-c',
          command,
        ],
      );

      if (result.exitCode != 0) {
        final scriptString = yellow.wrap(task.resolvedName);
        logger
          ..delayed('${red.wrap('Task failed:')} $scriptString')
          ..delayed(darkGray.wrap('-- script --'))
          ..delayed(command);

        final output = result.stdout as String;
        if (output.isNotEmpty) {
          logger
            ..delayed('\n')
            ..delayed(darkGray.wrap('-- output --'))
            ..delayed(output);
        }

        final error = result.stderr as String;
        if (error.isNotEmpty) {
          logger
            ..delayed('\n')
            ..delayed(darkGray.wrap('-- error --'))
            ..delayed(error);
        }
        return 1;
      }

      onSubTaskCompleted?.call(index);
    }

    return 0;
  }
}
