import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';

part 'resolved_hook.g.dart';

class ResolvedHook extends Equatable {
  const ResolvedHook({
    required this.files,
    required this.commands,
  });

  final List<String> files;
  final List<(List<String> files, HookCommand)> commands;

  @override
  List<Object?> get props => _$props;
}
