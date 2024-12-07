import 'dart:async';
import 'dart:io';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/utils/all_files.dart';
import 'package:mason_logger/mason_logger.dart';

part 'shell_task.g.dart';

base class ShellTask extends HookTask {
  const ShellTask({
    required super.include,
    required this.commands,
    super.exclude,
    super.name,
  });

  ShellTask.always({
    required this.commands,
    super.name,
  }) : super(include: [AllFiles()]);

  final List<String> Function(Iterable<String> files) commands;

  @override
  FutureOr<int> run(
    List<String> files, {
    Logger? logger,
    void Function(int)? completeSubTask,
  }) async {
    final coreCommand = switch (Platform.operatingSystem) {
      'windows' => 'cmd',
      _ => 'bash',
    };

    for (final (index, command) in commands(files).indexed) {
      final result = await Process.run(
        coreCommand,
        [
          '-c',
          command,
        ],
      );

      if (result.exitCode != 0) {
        final scriptString = yellow.wrap(resolvedName);
        logger
          ?..delayed('${red.wrap('Task failed:')} $scriptString')
          ..delayed(darkGray.wrap('-- script --'))
          ..delayed(command);

        if (result.stdout case final String out) {
          final output = out.trim();
          if (output.isNotEmpty) {
            logger
              ?..delayed('\n')
              ..delayed(darkGray.wrap('-- output --'))
              ..delayed(output);
          }
        }

        if (result.stderr case final String err) {
          final error = err.trim();
          if (error.isNotEmpty) {
            logger
              ?..delayed('\n')
              ..delayed(darkGray.wrap('-- error --'))
              ..delayed(error);
          }
        }
        return 1;
      }

      completeSubTask?.call(index);
    }

    return 0;
  }

  @override
  List<Object?> get props => _$props;
}
