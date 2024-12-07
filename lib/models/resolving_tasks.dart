import 'dart:async';

import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/shell_task.dart';
import 'package:uuid/uuid.dart';

class ResolvingTask {
  ResolvingTask({
    required this.files,
    required this.command,
    required Completer<int>? completer,
    required StreamController<int>? subTaskController,
  })  : _completer = completer,
        _subTaskController = subTaskController,
        id = const Uuid().v4() {
    _listener = _subTaskController?.stream.listen((index) {
      completedSubTaskIndex = index;
    });
  }

  StreamSubscription<int>? _listener;

  final String id;
  final Iterable<String> files;
  final Completer<int>? _completer;
  final StreamController<int>? _subTaskController;
  final HookTask command;

  bool get canRun => _completer != null;
  bool get hasCompleted => _completer?.isCompleted ?? false;
  bool get isRunning => canRun && !hasCompleted;
  bool get isError => code != null && code != 0;
  bool get isHalted => code == -99;
  bool get hasCompletedSubTasks {
    final task = command;
    if (task is! ShellTask) return true;
    if (isError && !isHalted) return false;

    final subTasks = task.label(files);

    if (subTasks.children.isEmpty) return true;

    Iterable<int> childLength(CommandLabel label) sync* {
      if (label.children.isEmpty) {
        yield 1;
        return;
      }

      for (final child in label.children) {
        yield* childLength(child);
      }
    }

    final length =
        childLength(subTasks).reduce((value, element) => value + element);

    return completedSubTaskIndex != length;
  }

  int? completedSubTaskIndex;

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
