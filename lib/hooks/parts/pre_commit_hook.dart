part of '../hook.dart';

/// {@macro hook}
///
/// The `allowEmpty` parameter determines whether the hook
/// should allow empty commits.
class PreCommitHook extends Hook {
  const PreCommitHook({
    required super.tasks,
    super.diffFilters = 'ACMR',
    super.diffArgs = const ['--staged', 'HEAD', '--name-only'],
    this.allowEmpty = false,
  });

  /// If true, the hook will exit successfully even if
  /// there are no files after the tasks have run
  final bool allowEmpty;
}
