import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';

part 'hook_command.g.dart';

base class HookCommand extends Equatable {
  const HookCommand({
    required this.pathPatterns,
    this.name,
  });

  final String? name;
  final List<Pattern> pathPatterns;

  String get resolvedName => switch (name) {
        final String name => name,
        _ => pathPatterns.map((e) {
            return switch (e) {
              Glob() => e.pattern,
              RegExp() => e.pattern,
              String() => e,
              _ => '$e',
            };
          }).join(', '),
      };
  @override
  List<Object?> get props => _$props;
}
