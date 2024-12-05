import 'dart:async';

import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/models/shell_script.dart';
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
  final HookCommand command;

  bool get canRun => _completer != null;
  bool get hasCompleted => _completer?.isCompleted ?? false;
  bool get isRunning => canRun && !hasCompleted;
  bool get isError => code != null && code != 0;
  bool get isHalted => code == -99;
  bool get hasCompletedSubTasks {
    final task = command;
    if (task is! ShellScript) return true;
    if (isError && !isHalted) return false;

    final subTasks = task.commands(files);

    return completedSubTaskIndex != subTasks.length;
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
