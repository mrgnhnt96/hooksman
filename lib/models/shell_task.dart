import 'dart:async';
import 'dart:io';

import 'package:hooksman/hooksman.dart';
import 'package:mason_logger/mason_logger.dart';

part 'shell_task.g.dart';

typedef ShellCommands = List<String> Function(Iterable<String> files);

class ShellTask extends SequentialTask {
  ShellTask({
    required super.include,
    required ShellCommands commands,
    super.exclude,
  })  : _commands = commands,
        super();

  final ShellCommands _commands;

  @override
  String get name => resolvedName;

  @override
  List<HookTask> tasks(Iterable<String> files) => [
        for (final (index, command) in _commands(files).indexed)
          _OneShellTask(
            command: command,
            index: index,
          ),
      ];

  @override
  List<Object?> get props => _$props;
}

class _OneShellTask extends HookTask {
  _OneShellTask({
    required this.command,
    required this.index,
  }) : super(include: [AllFiles()]);

  final String command;
  final int index;

  @override
  String? get name => command;

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String? p1) print,
    required void Function(int p1) completeSubTask,
  }) async {
    final coreCommand = switch (Platform.operatingSystem) {
      'windows' => 'cmd',
      _ => 'bash',
    };

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
    return 0;
  }

  @override
  List<Object?> get props => _$props;
}
