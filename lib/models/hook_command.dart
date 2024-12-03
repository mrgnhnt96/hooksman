import 'package:equatable/equatable.dart';

part 'hook_command.g.dart';

class HookCommand extends Equatable {
  const HookCommand({
    required this.pathPatterns,
  });

  final List<Pattern> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
