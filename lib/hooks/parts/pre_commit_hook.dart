part of '../hook.dart';

/// {@macro hook}
///
/// The `allowEmpty` parameter determines whether the hook
/// should allow empty commits.
class PreCommitHook extends Hook {
  const PreCommitHook({
    required super.tasks,
    super.diffFilters = _defaultDiffFilters,
    super.diffArgs = _defaultDiffArgs,
    this.allowEmpty = false,
    super.runInParallel,
  });

  const PreCommitHook.verbose({
    required super.tasks,
    super.diffFilters = _defaultDiffFilters,
    super.diffArgs = _defaultDiffArgs,
    this.allowEmpty = false,
    super.runInParallel,
  }) : super.verbose();

  static const _defaultDiffArgs = ['--staged', 'HEAD', '--name-only'];
  static const _defaultDiffFilters = 'ACMR';

  /// If true, the hook will exit successfully even if
  /// there are no files after the tasks have run
  final bool allowEmpty;
}
