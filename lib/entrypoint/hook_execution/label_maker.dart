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
  static const warning = '⚠️';

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

  String create(String loading) {
    return label(loading).join('\n');
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
        :startedTasks,
      ) = pendingHook;
      yield darkGray.wrap('');
      yield darkGray.wrap('Started Tasks: ${startedTasks.join(', ')}');
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
        :isHalted,
        :isRunning,
        :hasStarted,
        :hasCompleted
      ) = task;

      if (debug) {
        yield '';
        yield darkGray.wrap('Total depth: $depth');
        final status = switch ('') {
          _ when isRunning => 'Running',
          _ when isHalted => 'Halted',
          _ when isError => 'Error',
          _ when hasStarted => 'Started',
          _ when hasCompleted => 'Completed',
          _ when task.files.isEmpty => 'Skipped',
          _ when !isRunning => 'Pending',
          _ => '???',
        };
        yield darkGray.wrap('Status: $status');
      }
      yield* retrieveLabels(
        task,
        loading: loading,
        spacing: spacer,
      );
    }

    yield '\n';
  }

  String status(PendingTask task) {
    if (!debug) {
      return '';
    }

    final status = switch (task) {
      _ when task.subTasks.isNotEmpty => '-',
      _ when task.isRunning => 'R',
      _ when task.isHalted => 'H',
      _ when task.isError => 'E',
      _ when task.hasCompleted => 'C',
      _ when !task.hasStarted => 'P',
      _ => '?',
    };

    return darkGray.wrap(' ($status)') ?? '';
  }

  String? getIndexString(int index) => switch (debug) {
        true => darkGray.wrap('($index) '),
        _ => '',
      };

  String? icon(
    PendingTask pending, {
    required String? loading,
  }) {
    return switch (null) {
      _ when pending.isError => red.wrap(x),
      _ when pending.hasCompleted => green.wrap(checkMark),
      _ when pending.isHalted => blue.wrap(dot),
      _ when pending.files.isEmpty => yellow.wrap(down),
      _ when pending.subTasks.isNotEmpty => yellow.wrap(right),
      _ when !pending.hasStarted => magenta.wrap(loading),
      _ when pending.isRunning => yellow.wrap(loading),
      _ => red.wrap(warning),
    };
  }

  Iterable<String?> retrieveLabels(
    PendingTask pending, {
    required String? loading,
    required String spacing,
  }) sync* {
    final task = pending.resolvedTask;

    final iconString = icon(pending, loading: loading);
    final fileCountString = fileCount(task.fileCount);
    final indexString = getIndexString(task.index);

    final status = this.status(pending);
    yield trim(
      '$indexString$status$spacing$iconString ${task.name} $fileCountString',
    );

    if (pending.files.isEmpty) {
      return;
    }

    if (pending.isHalted) {
      if (!debug) {
        return;
      }
    }

    if (pending.hasCompleted && !pending.isError) {
      return;
    }

    for (final subPending in pending.subTasks) {
      final subTask = subPending.resolvedTask;

      final iconString = icon(subPending, loading: loading);

      final scriptString = switch (subTask) {
        final e when subPending.isError => red.wrap(e.name),
        final e => e.name,
      };

      final indexString = getIndexString(subTask.index);
      final fileCountString = switch (subTask.fileCount == subTask.fileCount) {
        true => '',
        _ => fileCount(subTask.fileCount),
      };
      final status = this.status(subPending);
      yield trim(
        '$indexString$status$spacing$spacer$iconString '
        '$scriptString $fileCountString',
      );

      if (subPending.hasCompleted && !subPending.isError) {
        continue;
      }

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
