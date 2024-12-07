import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';
import 'package:hooksman/models/task_label.dart';

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

  TaskLabel label(Iterable<String> files);

  List<String> filterFiles(Iterable<String> files) {
    Iterable<String> filesFor(Iterable<String> files) sync* {
      for (final file in files) {
        if (exclude.any((e) => e.allMatches(file).isNotEmpty)) {
          continue;
        }

        if (include.any((e) => e.allMatches(file).isNotEmpty)) {
          yield file;
        }
      }
    }

    return filesFor(files).toList();
  }

  @override
  List<Object?> get props => _$props;
}
