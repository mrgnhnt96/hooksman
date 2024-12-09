import 'dart:async';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/resolved_hook_task.dart';

class PendingTask {
  PendingTask({
    required this.files,
    required this.resolvedTask,
    required bool Function() isHalted,
    required Iterable<int> completedTasks,
    required Iterable<int> startedTasks,
  })  : _completedTasks = completedTasks,
        _startedTasks = startedTasks,
        _isHalted = isHalted {
    subTasks = resolvedTask.subTasks.map((task) {
      final subTask = PendingTask(
        files: files,
        resolvedTask: task,
        isHalted: isHalted,
        completedTasks: completedTasks,
        startedTasks: startedTasks,
      );

      return subTask;
    }).toList();

    Iterable<PendingTask> allTasks(PendingTask task) sync* {
      yield task;
      for (final subTask in task.subTasks) {
        yield* allTasks(subTask);
      }
    }

    taskMap = {
      for (final task in allTasks(this)) task.id: task,
    };
  }

  String get id => resolvedTask.original.id;
  final Iterable<String> files;
  final ResolvedHookTask resolvedTask;
  late final List<PendingTask> subTasks;
  late final Map<String, PendingTask> taskMap;

  final bool Function() _isHalted;
  bool get isHalted => _isHalted();

  final Iterable<int> _completedTasks;
  Set<int> get completedTasks => Set.unmodifiable(_completedTasks);

  final Iterable<int> _startedTasks;
  Set<int> get startedTasks => Set.unmodifiable(_startedTasks);

  final _codeCompleter = Completer<int>();
  String get name => resolvedTask.label.name;

  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask, int) completeTask,
    required void Function(HookTask) startTask,
  }) =>
      resolvedTask.original.run(
        files,
        print: print,
        completeTask: completeTask,
        startTask: startTask,
      );

  bool get hasCompleted {
    var isComplete = true;
    isComplete &= code != null && code != -99;
    isComplete &= completedTasks.contains(resolvedTask.index);
    isComplete &= subTasks.every((task) => task.hasCompleted);

    return isComplete;
  }

  bool get hasStarted => startedTasks.contains(resolvedTask.index);

  bool get isRunning {
    if (hasCompleted) return false;
    if (isHalted) return false;

    return hasStarted;
  }

  bool get isError {
    if (code == -99) return false;
    if (code != null && code != 0) return true;
    if (subTasks.any((task) => task.isError)) return true;

    return false;
  }

  Future<int>? get future => _codeCompleter.future;

  int? _code;
  int? get code => _code;
  set code(int? code) {
    if (code == null) return;
    if (_code != null) return;
    if (_codeCompleter.isCompleted) return;

    _code = code;
    _codeCompleter.complete(code);
  }

  void kill() {
    code = -99;
  }
}
