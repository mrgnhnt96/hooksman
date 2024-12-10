import 'dart:async';

import 'package:glob/glob.dart';
import 'package:hooksman/models/resolved_hook_task.dart';
import 'package:hooksman/models/task_label.dart';
import 'package:meta/meta.dart';
import 'package:uuid/uuid.dart';

abstract class HookTask {
  HookTask({
    required this.include,
    this.exclude = const [],
  }) : id = const Uuid().v4();

  final String id;
  final List<Pattern> include;
  final List<Pattern> exclude;

  String? get name;

  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String? string) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  });

  List<HookTask>? _subTasks;
  @nonVirtual
  List<HookTask> subTasks(Iterable<String> filePaths) =>
      _subTasks ??= getSubTasks(filePaths);

  List<HookTask> getSubTasks(Iterable<String> filePaths) => [];

  ResolvedHookTask resolve(List<String> filePaths, int index) {
    final filtered = filterFiles(filePaths);

    final subTasks = this.subTasks(filtered);

    return ResolvedHookTask(
      files: filtered,
      original: this,
      index: index,
      label: label(filtered),
      subTasks: subTasks.indexed.map((e) {
        final (i, task) = e;
        final subIndex = int.parse('${index}0$i');

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

  TaskLabel label(Iterable<String> filePaths) {
    // ensure files are filtered
    final filtered = filterFiles(filePaths);

    return TaskLabel(
      resolvedName,
      taskId: id,
      fileCount: filtered.length,
    );
  }

  List<String> filterFiles(Iterable<String> filePaths) {
    Iterable<String> filesFor(Iterable<String> filePaths) sync* {
      for (final path in filePaths) {
        if (exclude.any((e) => e.allMatches(path).isNotEmpty)) {
          continue;
        }

        if (include.any((e) => e.allMatches(path).isNotEmpty)) {
          yield path;
        }
      }
    }

    return filesFor(filePaths).toList();
  }
}
