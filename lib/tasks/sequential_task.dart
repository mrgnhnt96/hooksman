import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:meta/meta.dart';

/// A task that runs a series of sub-tasks sequentially on a set of files.
///
/// The [SequentialTask] class extends [HookTask] and is used to execute a list
/// of sub-tasks one after the other. Each sub-task is executed only if the
/// previous sub-task completes successfully (i.e., returns a zero exit code).
///
/// Example usage:
/// ```dart
/// SequentialTasks(
///   tasks: [
///     ShellTask(
///       include: [Glob('**.dart')],
///       commands: (filePaths) => [
///         'dart format ${filePaths.join(' ')}',
///       ],
///     ),
///     ShellTask(
///       include: [Glob('**.dart')],
///       commands: (filePaths) => [
///         'sip test --concurrent --bail',
///       ],
///     ),
///   ],
/// );
/// ```
///
/// The above example creates a [SequentialTasks] instance that runs two
/// [ShellTask] instances sequentially. The first task formats Dart files,
/// and the second task runs tests on the Dart files.
abstract class SequentialTask extends HookTask {
  SequentialTask({
    required super.include,
    super.exclude,
    this.name,
  });
  SequentialTask.always({
    this.name,
    super.exclude,
  }) : super.always();

  @override
  final String? name;

  @nonVirtual
  @override
  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  }) async {
    for (final task in subTasks(filePaths)) {
      startTask(task);
      final result = await task.run(
        filePaths,
        print: print,
        completeTask: completeTask,
        startTask: startTask,
      );

      completeTask(task, result);
      if (result != 0) return result;
    }

    completeTask(this, 0);

    return 0;
  }
}
