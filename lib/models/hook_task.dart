import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:glob/glob.dart';
import 'package:hooksman/models/resolved_hook_task.dart';
import 'package:hooksman/models/task_label.dart';
import 'package:uuid/uuid.dart';

part 'hook_task.g.dart';

abstract class HookTask extends Equatable {
  HookTask({
    required this.include,
    this.exclude = const [],
  }) : id = const Uuid().v4();

  final String id;
  final List<Pattern> include;
  final List<Pattern> exclude;

  String? get name;

  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(int) completeSubTask,
  });

  List<HookTask> subTasks(Iterable<String> files) => [];

  ResolvedHookTask resolve(List<String> files, int index) {
    final filtered = filterFiles(files);

    final subTasks = this.subTasks(filtered);

    return ResolvedHookTask(
      files: filtered,
      original: this,
      index: index,
      label: label(filtered),
      subTasks: subTasks.indexed.map((e) {
        final (i, task) = e;
        final subIndex = index * 100 + i;

        final subFiltered = task.filterFiles(filtered);

        return task.resolve(subFiltered, subIndex);
      }).toList(),
    );
  }

  String get patternName => include.map((e) {
        return switch (e) {
          Glob() => e.pattern,
          RegExp() => e.pattern,
          String() => e,
          _ => '$e',
        };
      }).join(', ');

  String get resolvedName => switch (name) {
        final String name => name,
        _ => patternName,
      };

  TaskLabel label(Iterable<String> files) {
    // ensure files are filtered
    final filtered = filterFiles(files);

    return TaskLabel(
      resolvedName,
      taskId: id,
      fileCount: filtered.length,
    );
  }

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
