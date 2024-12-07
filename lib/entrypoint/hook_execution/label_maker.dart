import 'dart:io' as io;

import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:hooksman/models/pending_task.dart';
import 'package:hooksman/models/resolved_hook_task.dart';
import 'package:hooksman/models/task_label.dart';
import 'package:mason_logger/mason_logger.dart';

class LabelMaker {
  const LabelMaker({
    required io.Stdout stdout,
    required this.pendingHook,
    required this.nameOfHook,
    this.debug = false,
  }) : _stdout = stdout;

  final io.Stdout _stdout;
  final PendingHook pendingHook;
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

    if (debug) {
      final PendingHook(
        :isDead,
        :wasKilled,
        :completedTasks,
      ) = pendingHook;
      yield darkGray.wrap('');
      yield darkGray.wrap('Completed Tasks: ${completedTasks.join(', ')}');
      yield darkGray.wrap('Killed: $wasKilled');
      yield darkGray.wrap('Dead: $isDead');
    }

    for (final task in pendingHook.topLevelTasks) {
      final PendingTask(
        resolvedTask: ResolvedHookTask(
          label: TaskLabel(:depth),
        ),
        :isError,
      ) = task;

      yield '';
      yield darkGray.wrap('Total depth: $depth');
      yield darkGray.wrap('Is error: $isError');
      yield* retrieveLabels(
        task,
        loading: loading,
        spacing: spacer,
      );
    }

    yield '\n';
  }

  String? getIndexString(int index) => switch (debug) {
        true => darkGray.wrap('($index) '),
        _ => '',
      };

  String? icon(
    PendingTask task, {
    required String? loading,
  }) {
    if (task.resolvedTask.fileCount == 0) {
      return yellow.wrap(down);
    }

    if (task.isHalted) {
      return blue.wrap(dot);
    }

    if (task.isError) {
      return red.wrap(x);
    }

    if (task.hasCompleted) {
      return green.wrap(checkMark);
    }

    final icon = switch (true) {
      _ when task.subTasks.isNotEmpty => right,
      _ => loading,
    };

    return yellow.wrap(icon);
  }

  Iterable<String?> retrieveLabels(
    PendingTask pending, {
    required String? loading,
    required String spacing,
  }) sync* {
    final task = pending.resolvedTask;

    final iconString = switch (null) {
      _ when pending.isError => red.wrap(x),
      _ when pending.isHalted => blue.wrap(dot),
      _ when task.fileCount > 0 => yellow.wrap(down),
      _ when task.hasChildren => yellow.wrap(right),
      _
          when task.index != 0 &&
              !pending.completedTasks.contains(task.index - 1) =>
        magenta.wrap(loading),
      _ => yellow.wrap(loading),
    };

    final fileCountString = fileCount(task.fileCount);
    final indexString = getIndexString(task.index);

    yield trim(
      '$indexString$spacing$iconString ${task.name} $fileCountString',
    );

    if (pending.hasCompleted || pending.isHalted) {
      return;
    }

    for (final subPending in pending.subTasks) {
      final subTask = subPending.resolvedTask;

      final hasCompleted = pending.completedTasks.contains(subTask.index);
      final isWorking = !hasCompleted;

      final iconString = switch (isWorking) {
        true when pending.isError => red.wrap(x),
        true
            when subTask.index != 0 &&
                pending.completedTasks.contains(subTask.index - 1) =>
          magenta.wrap(loading),
        true => yellow.wrap(loading),
        _ when hasCompleted => green.wrap(checkMark),
        _ => yellow.wrap(dot),
      };

      final scriptString = switch (subTask) {
        final e when isWorking && pending.isError => red.wrap(e.name),
        final e => e.name,
      };

      final indexString = getIndexString(subTask.index);
      final fileCountString = switch (subTask.fileCount == subTask.fileCount) {
        true => '',
        _ => fileCount(subTask.fileCount),
      };

      yield trim(
        '$indexString$spacing$spacer$iconString $scriptString $fileCountString',
      );

      for (final subParent in subPending.subTasks) {
        yield* retrieveLabels(
          subParent,
          loading: loading,
          spacing: '$spacing$spacer$spacer',
        );
      }
    }
  }
}

const invisible = '\u{200B}';
const spacer = '^';
