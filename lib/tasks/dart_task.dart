import 'dart:async';

import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/tasks/hook_task.dart';

typedef Run = FutureOr<int> Function(List<String>);

/// A task that runs Dart code on a set of files.
///
/// The [DartTask] class extends [HookTask] and is used to execute custom Dart
/// code on the included files. The task is considered successful if the
/// provided [run] function returns a zero exit code.
///
/// Example usage:
/// ```dart
/// DartTask(
///   include: [Glob('**.dart')],
///   run: (filePaths) async {
///     print('Running custom task');
///     // Perform custom operations on the file paths
///     return 0; // Return 0 on success, non-zero on failure
///   },
/// );
/// ```
///
/// The above example creates a [DartTask] instance that runs custom Dart code
/// on all Dart files in the project.
class DartTask extends HookTask {
  DartTask({required super.include, required Run run, super.exclude, this.name})
    : _run = run;

  final Run _run;

  @override
  final String? name;

  @override
  Future<int> run(
    List<String> filePaths, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
    required String? workingDirectory,
  }) async {
    startTask(this);
    final paths = switch (workingDirectory) {
      final String cwd => [
        for (final path in filePaths)
          if (fs.path.isWithin(cwd, path))
            fs.path.relative(path, from: cwd)
          else
            path,
      ],
      null => filePaths.toList(),
    };

    final result = await _run(paths);

    completeTask(this, result);

    return result;
  }
}
