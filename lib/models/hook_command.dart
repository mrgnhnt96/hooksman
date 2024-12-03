import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';

part 'hook_command.g.dart';

class HookCommand extends Equatable {
  const HookCommand({
    required this.pathPatterns,
    required this.commands,
    this.workingDirectory,
  });

  final List<Glob> pathPatterns;
  final List<String> Function(Iterable<String> files) commands;

  /// defaults to the current working directory
  final String? workingDirectory;

  @override
  List<Object?> get props => _$props;
}
