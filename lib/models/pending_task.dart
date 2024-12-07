import 'dart:async';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/resolved_hook_task.dart';
import 'package:uuid/uuid.dart';

class PendingTask {
  PendingTask({
    required this.files,
    required this.resolvedTask,
    required Completer<int>? completer,
    required StreamController<int>? subTaskController,
  })  : _completer = completer,
        _subTaskController = subTaskController,
        id = const Uuid().v4() {
    _listener = _subTaskController?.stream.listen(completedTasks.add);

    subTasks = resolvedTask.subTasks.map((task) {
      final subTask = PendingTask(
        files: files,
        resolvedTask: task,
        completer: null,
        subTaskController: _subTaskController,
      );

      return subTask;
    }).toList();
  }

  StreamSubscription<int>? _listener;

  final String id;
  final Iterable<String> files;
  final Completer<int>? _completer;
  final StreamController<int>? _subTaskController;
  final ResolvedHookTask resolvedTask;

  late final List<PendingTask> subTasks;

  String get name => resolvedTask.label.name;

  FutureOr<int> run(
    List<String> files, {
    required void Function(String?) print,
    required void Function(HookTask) completeSubTask,
  }) =>
      resolvedTask.original.run(
        files,
        print: print,
        completeTask: completeSubTask,
      );

  bool get canRun => _completer != null;
  bool get hasCompleted =>
      (_completer?.isCompleted ?? false) &&
      subTasks.every((task) => task.hasCompleted);
  bool get isRunning => canRun && !hasCompleted;
  bool get isError =>
      (code != null && code != 0) || subTasks.any((task) => task.isError);
  bool get isHalted => code == -99 || subTasks.any((task) => task.isHalted);

  final completedTasks = <int>{};

  Future<int>? get future => _completer?.future;

  int? _code;
  int? get code => _code;
  set code(int? code) {
    if (code == null) return;
    if (_code != null) return;

    _listener?.cancel();

    _code = code;

    if (_completer == null || _completer.isCompleted) return;

    _completer.complete(code);
  }

  void kill() {
    code = -99;
  }
}
