import 'dart:async';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/resolved_hook_task.dart';
import 'package:uuid/uuid.dart';

class PendingTask {
  PendingTask({
    required this.files,
    required this.resolvedTask,
    required bool Function() isHalted,
    required Iterable<int> completedTasks,
  })  : _completedTasks = completedTasks,
        id = const Uuid().v4(),
        _isHalted = isHalted {
    subTasks = resolvedTask.subTasks.map((task) {
      final subTask = PendingTask(
        files: files,
        resolvedTask: task,
        isHalted: isHalted,
        completedTasks: completedTasks,
      );

      return subTask;
    }).toList();
  }

  final String id;
  final Iterable<String> files;
  final ResolvedHookTask resolvedTask;
  late final List<PendingTask> subTasks;

  final bool Function() _isHalted;
  bool get isHalted => _isHalted();

  final Iterable<int> _completedTasks;
  Set<int> get completedTasks => Set.unmodifiable(_completedTasks);

  final _codeCompleter = Completer<int>();
  String get name => resolvedTask.label.name;

  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask) completeTask,
  }) =>
      resolvedTask.original.run(
        files,
        print: print,
        completeTask: completeTask,
      );

  bool get hasCompleted {
    var isComplete = true;
    isComplete ^= _codeCompleter.isCompleted;
    isComplete ^= subTasks.every((task) => task.hasCompleted);

    return isComplete;
  }

  bool get isRunning {
    return !hasCompleted;
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
