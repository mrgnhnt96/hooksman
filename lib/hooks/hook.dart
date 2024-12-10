import 'package:equatable/equatable.dart';
import 'package:hooksman/models/resolved_hook.dart';
import 'package:hooksman/tasks/hook_task.dart';

part 'hook.g.dart';

/// The `Hook` class represents a Git hook configuration
/// that defines a set of tasks to be executed
/// during specific Git hook events. This class allows you
/// to automate checks, validations, or any
/// custom scripts to ensure code quality and consistency
/// across your repository.
///
/// ## Usage
///
/// To create a hook, instantiate the `Hook` class with the desired
/// tasks and optional parameters:
///
/// ```dart
/// import 'package:hooksman/hooksman.dart';
///
/// Hook main() {
///   return Hook(
///     tasks: [
///       ReRegisterHooks(),
///       ShellTask(
///         name: 'Lint & Format',
///         include: [Glob('**.dart')],
///         exclude: [Glob('**.g.dart')],
///         commands: (filePaths) => [
///           'dart analyze --fatal-infos ${filePaths.join(' ')}',
///           'dart format ${filePaths.join(' ')}',
///         ],
///       ),
///       ShellTask(
///         name: 'Build Runner',
///         include: [Glob('lib/models/**.dart')],
///         exclude: [Glob('**.g.dart')],
///         commands: (filePaths) => [
///           'sip run build_runner build',
///         ],
///       ),
///       ShellTask(
///         name: 'Tests',
///         include: [Glob('**.dart')],
///         exclude: [Glob('hooks/**')],
///         commands: (filePaths) => [
///           'sip test --concurrent --bail',
///         ],
///       ),
///     ],
///   );
/// }
/// ```
///
/// The `tasks` parameter is a list of tasks to be executed
/// by the hook. Each task can specify
/// file patterns to include or exclude, and the commands
/// or Dart code to run.
///
/// The `diffArgs` parameter allows you to specify how files
/// are compared with the working directory,
/// index, or commit.
///
/// The `diffFilters` parameter allows you
/// to specify the statuses of files to
/// include or exclude, such as `added`, `modified`, or `deleted`.
///
/// The `allowEmpty` parameter determines whether the hook
/// should allow empty commits.
///
/// The `backupFiles` parameter specifies whether the original
/// files should be backed up before running
/// the hook.
class Hook extends Equatable {
  Hook({
    required this.tasks,
    this.diffArgs = const [],
    this.allowEmpty = false,
    this.diffFilters,
    bool? backupFiles,
  }) : backupFiles = backupFiles ?? diffArgs.isEmpty;

  /// Defaults to ['--staged']
  final List<String> diffArgs;

  /// Defaults to 'ACMR'
  ///
  /// - A = Added
  /// - C = Copied
  /// - M = Modified
  /// - R = Renamed
  ///
  /// Check out the git [docs](https://git-scm.com/docs/git-diff#Documentation/git-diff.txt---diff-filterACDMRTUXB82308203) to view more options
  final String? diffFilters;
  late final List<HookTask> tasks;

  /// If true, the original files will be backed up before running the hook
  ///
  /// Defaults to true if [diffArgs] is empty
  final bool backupFiles;

  /// If true, the hook will exit successfully even if
  /// there are no files after the tasks have run
  final bool allowEmpty;

  ResolvedHook resolve(List<String> filePaths) {
    final resolvedTasks = tasks.indexed.map((e) {
      final (index, task) = e;

      return task.resolve(filePaths, index + 1);
    }).toList();

    return ResolvedHook(
      filePaths: filePaths,
      tasks: resolvedTasks,
    );
  }

  @override
  List<Object?> get props => _$props;
}
