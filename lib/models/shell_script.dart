import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'shell_script.g.dart';

base class ShellScript extends HookCommand {
  const ShellScript({
    required super.pathPatterns,
    required this.commands,
    super.name,
  });

  ShellScript.always({
    required this.commands,
    super.name,
  }) : super(pathPatterns: [AllFiles()]);

  final List<String> Function(Iterable<String> files) commands;

  @override
  List<Object?> get props => _$props;
}
