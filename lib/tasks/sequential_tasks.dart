import 'package:hooksman/tasks/hook_task.dart';
import 'package:hooksman/tasks/sequential_task.dart';
import 'package:hooksman/tasks/shell_task.dart';
import 'package:hooksman/utils/all_files.dart';

/// A task that runs a series of sub-tasks sequentially on a set of files.
///
/// The [SequentialTasks] class extends [SequentialTask] and is used to
/// execute a list
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
class SequentialTasks extends SequentialTask {
  SequentialTasks({
    required List<HookTask> tasks,
    this.name,
    List<Pattern>? include,
    super.exclude,
  })  : _tasks = tasks,
        super(include: include ?? [AllFiles()]);

  SequentialTasks.always({
    required List<HookTask> tasks,
    this.name,
  })  : _tasks = tasks,
        super.always();

  @override
  final String? name;

  final List<HookTask> _tasks;

  @override
  List<HookTask> getSubTasks(Iterable<String> filePaths) => _tasks;
}
