import 'package:equatable/equatable.dart';
import 'package:hooksman/models/resolved_hook.dart';
import 'package:hooksman/tasks/hook_task.dart';

part 'hook.g.dart';
part 'parts/any_hook.dart';
part 'parts/pre_commit_hook.dart';
part 'parts/pre_push_hook.dart';

/// {@template hook}
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
/// The `backupFiles` parameter specifies whether the original
/// files should be backed up before running
/// the hook.
/// {@endtemplate}
sealed class Hook extends Equatable {
  const Hook({
    required this.tasks,
    required this.diffFilters,
    required this.diffArgs,
    this.runInParallel = true,
  }) : verbose = false;

  const Hook.verbose({
    required this.tasks,
    required this.diffFilters,
    required this.diffArgs,
    this.runInParallel = true,
  }) : verbose = true;

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
  final String diffFilters;
  final List<HookTask> tasks;
  final bool runInParallel;

  final bool verbose;

  ResolvedHook resolve(List<String> filePaths) {
    final resolvedTasks = tasks.indexed.map((e) {
      final (index, task) = e;

      return task.resolve(filePaths, index + 1);
    }).toList();

    return ResolvedHook(
      filePaths: filePaths,
      tasks: resolvedTasks,
      runInParallel: runInParallel,
    );
  }

  @override
  List<Object?> get props => _$props;

  bool get shouldRunOnEmpty => tasks.any((e) => e.shouldAlwaysRun);
}
