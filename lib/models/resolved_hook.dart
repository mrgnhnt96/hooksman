import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_task.dart';

part 'resolved_hook.g.dart';

class ResolvedHook extends Equatable {
  const ResolvedHook({
    required this.files,
    required this.commands,
  });

  final List<String> files;
  final List<(Iterable<String> files, HookTask)> commands;

  @override
  List<Object?> get props => _$props;
}
