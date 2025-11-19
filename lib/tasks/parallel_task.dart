import 'dart:async';

import 'package:hooksman/hooksman.dart';
import 'package:meta/meta.dart';

/// A task that runs a series of sub-tasks in parallel on a set of files.
///
/// The [ParallelTasks] class extends [HookTask] and is used to execute a list
/// of sub-tasks concurrently. Each sub-task is executed independently of the
/// others, and the overall task completes successfully only if all sub-tasks
/// complete successfully (i.e., return a zero exit code).
///
/// Example usage:
/// ```dart
/// ParallelTasks(
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
/// The above example creates a [ParallelTasks] instance that runs two
/// [ShellTask] instances concurrently. The first task formats Dart files,
/// and the second task runs tests on the Dart files.
class ParallelTasks extends HookTask {
  ParallelTasks({required List<HookTask> tasks, super.exclude, this.name})
    : _tasks = tasks,
      super.always();

  @override
  final String? name;

  final List<HookTask> _tasks;

  @override
  List<HookTask> subTasks(Iterable<String> filePaths) => _tasks;

  @nonVirtual
  @override
  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
    required String? workingDirectory,
  }) async {
    final futures = <Future<int>>[];

    for (final task in resolveSubTasks(filePaths)) {
      startTask(task);
      Future<int> value() async {
        return await task.run(
          filePaths,
          print: print,
          completeTask: completeTask,
          startTask: startTask,
          workingDirectory: workingDirectory,
        );
      }

      futures.add(
        value().then((code) {
          completeTask(task, code);

          if (code != 0) {
            // ignore: only_throw_errors
            throw code;
          }

          return code;
        }),
      );
    }

    try {
      await Future.wait(futures);
    } on int catch (code) {
      return code;
    }

    completeTask(this, 0);

    return 0;
  }
}
