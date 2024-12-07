import 'dart:async';

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
    required void Function(int) completeSubTask,
  }) =>
      resolvedTask.original.run(
        files,
        print: print,
        completeSubTask: completeSubTask,
      );

  bool get canRun => _completer != null;
  bool get hasCompleted => _completer?.isCompleted ?? false;
  bool get isRunning => canRun && !hasCompleted;
  bool get isError => code != null && code != 0;
  bool get isHalted => code == -99;
  bool get hasCompletedSubTasks {
    final task = resolvedTask;
    if (isError && !isHalted) return false;

    final subTasks = task.label;

    return completedTasks.length != subTasks.depth;
  }

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
