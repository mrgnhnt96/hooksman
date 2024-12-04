import 'dart:async';

import 'package:git_hooks/models/hook_command.dart';

class ResolvingTask {
  ResolvingTask({
    required this.files,
    required this.command,
    required Completer<int>? completer,
  }) : _completer = completer;

  final Iterable<String> files;
  final Completer<int>? _completer;
  final HookCommand command;

  bool get canRun => _completer != null;
  bool get hasCompleted => _completer?.isCompleted ?? false;
  bool get isRunning => canRun && !hasCompleted;
  bool get isError => code != null && code != 0;
  bool get isHalted => code == -1;

  Future<int>? get future => _completer?.future;

  int? _code;
  int? get code => _code;
  set code(int? code) {
    if (code == null) return;
    if (_code != null) return;
    _code = code;

    if (_completer == null || _completer.isCompleted) return;

    _completer.complete(code);
  }

  void kill() {
    code = -1;
  }
}
