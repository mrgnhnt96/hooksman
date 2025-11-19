import 'dart:async';

import 'package:glob/glob.dart';
import 'package:hooksman/models/resolved_hook_task.dart';
import 'package:hooksman/models/task_label.dart';
import 'package:hooksman/utils/all_files.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

/// An abstract class representing a task to be executed as part of a Git hook.
///
/// Subclasses must implement the [run] method to define the task's behavior.
///
/// Tasks can include or exclude specific files based on patterns, and can have
/// sub-tasks that are executed conditionally based
/// on the files being processed.
///
/// ### Usage
///
/// To create a custom hook task, extend this class
/// and implement the [run] method:
///
/// ```dart
/// class MyCustomTask extends HookTask {
///   MyCustomTask() : super(include: [Glob('**.dart')]);
///
///   @override
///   FutureOr<int> run(
///     List<String> filePaths, {
///     required void Function(String? string) print,
///     required void Function(HookTask, int) completeTask,
///     required void Function(HookTask) startTask,
///   }) async {
///     // Task implementation here
///     return 0; // Return 0 on success, non-zero on failure
///   }
/// }
/// ```
///
/// To use the custom task in a hook:
///
/// ```dart
/// Hook main() {
///   return Hook(
///     tasks: [MyCustomTask()],
///   );
/// }
/// ```
abstract class HookTask {
  HookTask({
    required this.include,
    this.exclude = const [],
    this.workingDirectory,
  }) : _always = false,
       id = const Uuid().v4();

  /// Creates a task that always runs, even if no files are being
  /// processed or if the files do not match the task's patterns.
  HookTask.always({this.exclude = const [], this.workingDirectory})
    : include = [AllFiles()],
      _always = true,
      id = const Uuid().v4();

  /// The unique identifier for the task.
  final String id;

  /// The list of patterns to include files.
  final List<Pattern> include;

  /// The list of patterns to exclude files.
  final List<Pattern> exclude;

  final String? workingDirectory;

  /// Whether the task should always run,
  /// regardless of the files being processed.
  final bool _always;

  /// The name of the task.
  String? get name;

  /// Runs the task with the given file paths.
  ///
  /// [filePaths] is the list of file paths to process.
  /// [print] is a function to print messages.
  /// [completeTask] is a function to mark the task as complete.
  /// [startTask] is a function to mark the task as started.
  ///
  /// Returns a FutureOr<int> indicating the result of the task.
  /// A return value of 0 indicates success, while a non-zero value indicates
  /// failure.
  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String? string) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
    required String? workingDirectory,
  });

  List<HookTask>? _subTasks;

  /// Resolves the list of sub-tasks for the given file paths.
  ///
  /// [filePaths] is the list of file paths to process post-filtering.
  @nonVirtual
  List<HookTask> resolveSubTasks(Iterable<String> filePaths) {
    if (_subTasks case final tasks?) return tasks;

    final tasks = subTasks(filePaths);

    Iterable<HookTask> filterTasks() sync* {
      for (final task in tasks) {
        final filtered = task.filterFiles(filePaths);

        if (filtered.isNotEmpty) {
          yield task;
        }
      }
    }

    return _subTasks ??= filterTasks().toList();
  }

  /// Gets the list of sub-tasks for the given file paths.
  ///
  /// [filePaths] is the list of file paths to process.
  List<HookTask> subTasks(Iterable<String> filePaths) => [];

  /// Resolves the task with the given file paths and index.
  ///
  /// [filePaths] is the list of file paths to process.
  /// [index] is the index of the task.
  ///
  /// The index is used during logging to create identifiable task labels
  /// for each task. Failure to provide a unique index for each task
  /// may result in duplicate task labels and incorrect logging.
  ResolvedHookTask resolve(List<String> filePaths, int index) {
    final filtered = filterFiles(filePaths);

    final subTasks = resolveSubTasks(filtered);

    return ResolvedHookTask(
      workingDirectory: workingDirectory,
      files: filtered,
      original: this,
      always: _always,
      index: index,
      label: label(filtered),
      subTasks: subTasks.indexed.map((e) {
        final (i, task) = e;
        final subIndex = int.parse('${index}0$i');

        final subFiltered = task.filterFiles(filtered);

        return task.resolve(subFiltered, subIndex);
      }).toList(),
    );
  }

  /// Gets the pattern name for the task.
  ///
  /// Returns a string representing the pattern name.
  String get patternName => switch (_always) {
    true => 'always',
    false =>
      include
          .map((e) {
            return switch (e) {
              Glob() => e.pattern,
              RegExp() => e.pattern,
              String() => e,
              _ => '$e',
            };
          })
          .join(', '),
  };

  /// Gets the resolved name for the task.
  ///
  /// Returns a string representing the resolved name.
  String get resolvedName => switch (name) {
    final String name => name,
    _ => patternName,
  };

  bool get shouldAlwaysRun {
    if (_always) return true;

    final subTasks = this.subTasks([]);

    return subTasks.any((e) => e.shouldAlwaysRun);
  }

  /// Creates a label for the task with the given file paths.
  ///
  /// [filePaths] is the list of file paths to process.
  ///
  /// Returns a TaskLabel.
  TaskLabel label(Iterable<String> filePaths) {
    // ensure files are filtered
    final filtered = filterFiles(filePaths);

    return TaskLabel(resolvedName, taskId: id, fileCount: filtered.length);
  }

  /// Filters the given file paths based on the [include] and [exclude]
  /// patterns.
  ///
  /// [filePaths] is the list of file paths to filter.
  ///
  /// Returns a list of filtered file paths.
  List<String> filterFiles(Iterable<String> filePaths) {
    Iterable<String> filesFor(Iterable<String> filePaths) sync* {
      for (final path in filePaths) {
        if (exclude.any((e) => e.allMatches(path).isNotEmpty)) {
          continue;
        }

        if (include.any((e) => e.allMatches(path).isNotEmpty)) {
          yield path;
        }
      }
    }

    return filesFor(filePaths).toList();
  }
}
