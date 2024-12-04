import 'package:equatable/equatable.dart';

part 'hook_command.g.dart';

class HookCommand extends Equatable {
  const HookCommand({
    required this.pathPatterns,
    this.name,
  });

  final String? name;
  final List<Pattern> pathPatterns;

  @override
  List<Object?> get props => _$props;
}
