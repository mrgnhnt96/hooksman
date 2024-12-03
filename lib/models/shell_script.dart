import 'package:equatable/equatable.dart';
import 'package:git_hooks/models/hook_command.dart';
import 'package:glob/glob.dart';

part 'shell_script.g.dart';

class ShellScript extends Equatable implements HookCommand {
  const ShellScript({
    required this.pathPatterns,
    required this.commands,
  });

  final List<String> Function(Iterable<String> files) commands;
  @override
  final List<Glob> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
