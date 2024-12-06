import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';

part 'hook.g.dart';

class Hook extends Equatable {
  const Hook({
    required this.commands,
    this.diffArgs = const [],
    this.diffFilters,
  });

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
  final List<HookCommand> commands;

  @override
  List<Object?> get props => _$props;
}
