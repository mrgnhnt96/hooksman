import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';

part 'hook_task.g.dart';

abstract class HookTask extends Equatable {
  const HookTask({
    required this.include,
    this.exclude = const [],
    this.name,
  });

  final String? name;
  final List<Pattern> include;
  final List<Pattern> exclude;
  FutureOr<int> run(List<String> files);

  String get resolvedName => switch (name) {
        final String name => name,
        _ => include.map((e) {
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
