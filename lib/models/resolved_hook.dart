import 'package:equatable/equatable.dart';
import 'package:hooksman/models/resolved_hook_task.dart';

part 'resolved_hook.g.dart';

class ResolvedHook extends Equatable {
  const ResolvedHook({
    required this.files,
    required this.tasks,
  });

  final List<String> files;
  final List<ResolvedHookTask> tasks;

  @override
  List<Object?> get props => _$props;
}
