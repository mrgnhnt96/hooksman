import 'dart:async';
import 'dart:io';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/utils/all_files.dart';
import 'package:mason_logger/mason_logger.dart';

part 'shell_task.g.dart';

typedef ShellCommands = List<String> Function(Iterable<String> files);

class ShellTask extends HookTask {
  const ShellTask({
    required super.include,
    required ShellCommands commands,
    super.exclude,
    super.name,
  }) : _commands = commands;

  ShellTask.always({
    required ShellCommands commands,
    super.name,
  })  : _commands = commands,
        super(include: [AllFiles()]);

  final ShellCommands _commands;

  @override
  CommandLabel label(Iterable<String> files) => CommandLabel(
        resolvedName,
        children: _commands(files).map(CommandLabel.new).toList(),
      );

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(int) completeSubTask,
  }) async {
    final coreCommand = switch (Platform.operatingSystem) {
      'windows' => 'cmd',
      _ => 'bash',
    };

    for (final (index, command) in _commands(files).indexed) {
      final result = await Process.run(
        coreCommand,
        [
          '-c',
          command,
        ],
      );

      if (result.exitCode != 0) {
        final scriptString = yellow.wrap(resolvedName);
        print('${red.wrap('Task failed:')} $scriptString');
        print(darkGray.wrap('-- script --'));
        print(command);

        if (result.stdout case final String out) {
          final output = out.trim();
          if (output.isNotEmpty) {
            print('\n');
            print(darkGray.wrap('-- output --'));
            print(output);
          }
        }

        if (result.stderr case final String err) {
          final error = err.trim();
          if (error.isNotEmpty) {
            print('\n');
            print(darkGray.wrap('-- error --'));
            print(error);
          }
        }
        return 1;
      }

      completeSubTask.call(index);
    }

    return 0;
  }

  @override
  List<Object?> get props => _$props;
}
