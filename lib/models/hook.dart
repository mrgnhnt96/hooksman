import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';

part 'hook.g.dart';

class Hook extends Equatable {
  const Hook({
    required this.commands,
    this.diffFilters = const [],
  });

  final List<String> diffFilters;
  final List<HookCommand> commands;

  @override
  List<Object?> get props => _$props;
}
