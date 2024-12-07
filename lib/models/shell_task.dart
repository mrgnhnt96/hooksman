import 'package:git_hooks/models/hook_task.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'shell_task.g.dart';

base class ShellTask extends HookTask {
  const ShellTask({
    required super.include,
    required this.commands,
    super.exclude,
    super.name,
  });

  ShellTask.always({
    required this.commands,
    super.name,
  }) : super(include: [AllFiles()]);

  final List<String> Function(Iterable<String> files) commands;

  @override
  List<Object?> get props => _$props;
}
