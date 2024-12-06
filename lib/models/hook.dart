import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_task.dart';

part 'hook.g.dart';

class Hook extends Equatable {
  Hook({
    required this.commands,
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
  final List<HookTask> commands;

  /// If true, the original files will be backed up before running the hook
  ///
  /// Defaults to true if [diffArgs] is empty
  final bool backupFiles;

  /// If true, the hook will exit successfully even if
  /// there are no files after the tasks have run
  final bool allowEmpty;

  @override
  List<Object?> get props => _$props;
}
