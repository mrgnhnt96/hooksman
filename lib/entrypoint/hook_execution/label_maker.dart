import 'dart:io' as io;

import 'package:hooksman/models/dart_task.dart';
import 'package:hooksman/models/resolving_tasks.dart';
import 'package:hooksman/models/shell_task.dart';
import 'package:mason_logger/mason_logger.dart';

class LabelMaker {
  const LabelMaker({
    required io.Stdout stdout,
    required this.tasks,
    required this.nameOfHook,
  }) : _stdout = stdout;

  final io.Stdout _stdout;
  final List<ResolvingTask> tasks;
  final String nameOfHook;

  static const down = '↓';
  static const right = '→';
  static const dot = '•';
  static const checkMark = '✔️';
  static const x = 'ⅹ';

  int get maxWidth => _stdout.terminalColumns;

  String? fileCount(int count) {
    final string = switch (count) {
      0 => '- no files',
      1 => '- 1 file',
      _ => '- $count files',
    };

    return darkGray.wrap(string);
  }

  String? icon(
    dynamic command, // HookCommand | String
    int fileCount, {
    required String? loading,
    required bool isComplete,
    required bool isError,
    required bool isHalted,
  }) {
    if (fileCount == 0) {
      return yellow.wrap(down);
    }

    if (isHalted) {
      return blue.wrap(dot);
    }

    if (isError) {
      return red.wrap(x);
    }

    if (isComplete) {
      return green.wrap(checkMark);
    }

    final icon = switch (command) {
      ShellTask() => right,
      DartTask() => loading,
      String() => loading,
      _ => '',
    };

    return yellow.wrap(icon);
  }

  String trim(String string) {
    final trimmed = string.split('').take(maxWidth - 1).toList();

    if (trimmed.length < string.length) {
      trimmed.add('…');
    }

    return trimmed.join();
  }

  String create(String loadingFrame) {
    final loading = yellow.wrap(loadingFrame);

    return label(loading).join('\n');
  }

  Iterable<String?> label(String? loading) sync* {
    yield 'Running tasks for $nameOfHook';
    for (final task in tasks) {
      final ResolvingTask(
        :command,
        :code,
        :hasCompleted,
        :isError,
        :isHalted,
        :files,
        :hasCompletedSubTasks,
        :completedSubTaskIndex,
      ) = task;

      final count = fileCount(files.length);
      final iconString = icon(
        command,
        files.length,
        isComplete: hasCompleted,
        isError: isError,
        isHalted: isHalted,
        loading: loading,
      );

      yield trim('  $iconString ${command.resolvedName} $count');

      if (files.isEmpty) {
        continue;
      }

      if (command is! ShellTask) {
        continue;
      }

      if (hasCompleted && hasCompletedSubTasks) {
        continue;
      }

      for (final (index, script) in command.commands(files).indexed) {
        final hasCompleted =
            completedSubTaskIndex != null && index - 1 < completedSubTaskIndex;

        final isWorking = (completedSubTaskIndex == null && index == 0) ||
            index - 1 == completedSubTaskIndex;

        final iconString = switch (isWorking) {
          true when isError => red.wrap(x),
          true => loading,
          _ when hasCompleted => green.wrap(checkMark),
          _ => yellow.wrap(dot),
        };

        final scriptString = switch (script) {
          final e when isWorking && isError => red.wrap(e),
          final e => e,
        };

        yield trim('    $iconString $scriptString');
      }
    }

    yield '\n';
  }
}
