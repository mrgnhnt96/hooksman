import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';

part 'hook_task.g.dart';

base class HookTask extends Equatable {
  const HookTask({
    required this.pathPatterns,
    this.excludePatterns = const [],
    this.name,
  });

  final String? name;
  final List<Pattern> pathPatterns;
  final List<Pattern> excludePatterns;

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
