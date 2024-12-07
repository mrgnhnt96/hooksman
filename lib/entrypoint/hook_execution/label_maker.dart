import 'dart:io' as io;

import 'package:hooksman/models/resolving_task.dart';
import 'package:hooksman/models/task_label.dart';
import 'package:mason_logger/mason_logger.dart';

class LabelMaker {
  const LabelMaker({
    required io.Stdout stdout,
    required this.tasks,
    required this.nameOfHook,
    this.debug = false,
  }) : _stdout = stdout;

  final io.Stdout _stdout;
  final List<ResolvingTask> tasks;
  final String nameOfHook;
  final bool debug;

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

  String trim(String string) {
    final spacerCounts = RegExp(r'\^').allMatches(string).length;
    final max = maxWidth - (spacerCounts * 2) - 1;
    final trimmed = string.split('').take(max).toList();

    if (trimmed.length < string.length) {
      trimmed.add('…');
    }

    return trimmed.join().replaceAll(RegExp(r'\^'), '$invisible  $invisible');
  }

  String create(String loadingFrame) {
    final loading = yellow.wrap(loadingFrame);

    return label(
      loading,
    ).join('\n');
  }

  Iterable<String?> label(
    String? loading,
  ) sync* {
    yield 'Running tasks for $nameOfHook';
    for (final task in tasks) {
      final ResolvingTask(
        resolvedTask: command,
        :code,
        :isError,
        :isHalted,
        :files,
        :completedTasks,
      ) = task;

      final label = command.label;

      if (debug) {
        yield darkGray.wrap('');
        yield darkGray.wrap('Total depth: ${label.depth}');
        yield darkGray.wrap('Completed Tasks: ${completedTasks.join(', ')}');
        yield darkGray.wrap('Is error: $isError');
        yield darkGray.wrap('Is halted: $isHalted');
      }

      yield* retrieveLabels(
        label,
        index: command.index,
        loading: loading,
        spacing: spacer,
        completedTasks: completedTasks,
        isError: isError,
        isHalted: isHalted,
      );
    }

    yield '\n';
  }

  String? getIndexString(int index) => switch (debug) {
        true => darkGray.wrap('($index) '),
        _ => '',
      };

  String? icon(
    TaskLabel command, // HookCommand | String
    int fileCount, {
    required String? loading,
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

    // if (isComplete) {
    //   return green.wrap(checkMark);
    // }

    final icon = switch (command) {
      _ when command.hasChildren => right,
      _ => loading,
    };

    return yellow.wrap(icon);
  }

  Iterable<String?> retrieveLabels(
    TaskLabel parentLabel, {
    required int index,
    required String? loading,
    required String spacing,
    required Set<int> completedTasks,
    required bool isError,
    required bool isHalted,
  }) sync* {
    final iconString = switch (null) {
      _ when isError => red.wrap(x),
      _ when isHalted => blue.wrap(dot),
      _ when parentLabel.fileCount > 0 => yellow.wrap(down),
      _ when parentLabel.hasChildren => yellow.wrap(right),
      _ when index != 0 && !completedTasks.contains(index - 1) =>
        magenta.wrap(loading),
      _ => yellow.wrap(loading),
    };

    final fileCountString = fileCount(parentLabel.fileCount);
    final indexString = getIndexString(index);

    yield trim(
      '$indexString$spacing$iconString ${parentLabel.name} $fileCountString',
    );

    if (parentLabel.fileCount == 0) {
      return;
    }

    // if (hasCompleted && hasCompletedSubTasks) {
    //   return;
    // }

    // final children = parentLabel.children;
    // for (final label in children) {
    //   final hasCompleted = completedTasks.contains(label.index);
    //   final isWorking = !hasCompleted;

    //   final iconString = switch (isWorking) {
    //     true when isError => red.wrap(x),
    //     true
    //         when label.index != 0 && completedTasks.contains(label.index - 1) =>
    //       magenta.wrap(loading),
    //     true => yellow.wrap(loading),
    //     _ when hasCompleted => green.wrap(checkMark),
    //     _ => yellow.wrap(dot),
    //   };

    //   final scriptString = switch (label) {
    //     final e when isWorking && isError => red.wrap(e.name),
    //     final e => e,
    //   };

    //   final indexString = getIndexString(label.index);
    //   final fileCountString =
    //       switch (label.fileCount == parentLabel.fileCount) {
    //     true => '',
    //     _ => fileCount(label.fileCount),
    //   };
    //   yield trim(
    //     '$indexString$spacing$spacer$iconString $scriptString $fileCountString',
    //   );

    //   for (final child in label.children) {
    //     yield* retrieveLabels(
    //       child,
    //       loading: loading,
    //       spacing: '$spacing$spacer$spacer',
    //       completedTasks: completedTasks,
    //       isError: isError,
    //       isHalted: isHalted,
    //     );
    //   }
    // }
  }
}

const invisible = '\u{200B}';
const spacer = '^';
