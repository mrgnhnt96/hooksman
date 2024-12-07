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
  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(int) completeSubTask,
  });

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

  CommandLabel label(Iterable<String> files);

  @override
  List<Object?> get props => _$props;
}

class CommandLabel {
  const CommandLabel(
    this.name, {
    this.children = const [],
  });

  final String name;
  final List<CommandLabel> children;

  bool get hasChildren => children.isNotEmpty;

  int get length {
    if (!hasChildren) {
      return 1;
    }

    return children.length;
  }

  int get depth {
    if (!hasChildren) {
      return 1;
    }

    return children
        .map((e) => e.depth)
        .reduce((value, element) => value > element ? value : element);
  }

  @override
  String toString() => name;
}
