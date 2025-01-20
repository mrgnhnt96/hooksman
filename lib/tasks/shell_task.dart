import 'dart:async';
import 'dart:io';

import 'package:hooksman/tasks/hook_task.dart';
import 'package:hooksman/tasks/sequential_task.dart';
import 'package:hooksman/utils/all_files.dart';
import 'package:mason_logger/mason_logger.dart';

typedef ShellCommands = List<String> Function(Iterable<String>);

/// A task that runs a series of shell commands sequentially on a set of files.
///
/// The [ShellTask] class extends [SequentialTask] and is used to execute a list
/// of shell commands on a set of files. The commands are provided via a
/// [ShellCommands] function, which takes an iterable of file paths and returns
/// a list of shell commands to be executed.
///
/// Example usage:
/// ```dart
/// ShellTask(
///   name: 'Lint & Format',
///   include: [Glob('**.dart')],
///   exclude: [Glob('**.g.dart')],
///   commands: (filePaths) => [
///     'dart analyze --fatal-infos ${filePaths.join(' ')}',
///     'dart format ${filePaths.join(' ')}',
///   ],
/// );
/// ```
///
/// This example creates a [ShellTask] named 'Lint & Format' that includes all
/// Dart files except those ending with '.g.dart'. It runs the `dart analyze`
/// and `dart format` commands on the included files.
class ShellTask extends SequentialTask {
  ShellTask({
    required super.include,
    required ShellCommands commands,
    super.exclude,
    String? name,
  })  : _commands = commands,
        _name = name,
        _always = false,
        super();

  ShellTask.always({
    required ShellCommands commands,
    String? name,
  })  : _commands = commands,
        _name = name,
        _always = true,
        super.always();

  final ShellCommands _commands;

  final bool _always;

  final String? _name;
  @override
  String get name => _name ?? patternName;

  @override
  List<HookTask> getSubTasks(Iterable<String> filePaths) => [
        for (final (index, command) in _commands(filePaths).indexed)
          switch (_always) {
            true => _OneShellTask.always,
            false => _OneShellTask.new,
          }(
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

  _OneShellTask.always({
    required this.command,
    required this.index,
  }) : super.always();

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
