import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/utils/all_files.dart';

part 'shell_script.g.dart';

class ShellScript extends Equatable implements HookCommand {
  const ShellScript({
    required this.pathPatterns,
    required this.commands,
  });

  ShellScript.always({
    required this.commands,
  }) : pathPatterns = [AllFiles()];

  final List<String> Function(Iterable<String> files) commands;
  @override
  final List<Pattern> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
