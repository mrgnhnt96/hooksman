import 'dart:async';
import 'dart:io';

import 'package:hooksman/hooksman.dart';
import 'package:mason_logger/mason_logger.dart';

typedef ShellCommands = List<String> Function(Iterable<String> files);

class ShellTask extends SequentialTask {
  ShellTask({
    required super.include,
    required ShellCommands commands,
    super.exclude,
    String? name,
  })  : _commands = commands,
        _name = name,
        super();

  final ShellCommands _commands;

  final String? _name;
  @override
  String get name => _name ?? patternName;

  @override
  List<HookTask> getSubTasks(Iterable<String> files) => [
        for (final (index, command) in _commands(files).indexed)
          _OneShellTask(
            command: command,
            index: index,
          ),
      ];
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
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  }) async {
    startTask(this);
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

    completeTask(this, result.exitCode);

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
    }

    return result.exitCode;
  }
}
