import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';

part 'hook_command.g.dart';

class HookCommand extends Equatable {
  const HookCommand({
    required this.pathPatterns,
  });

  final List<Glob> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
