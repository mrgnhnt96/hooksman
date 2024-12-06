import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:git_hooks/entrypoint/hook_execution/task_runner.dart';
import 'package:git_hooks/models/resolved_hook.dart';
import 'package:git_hooks/models/resolving_tasks.dart';
import 'package:git_hooks/models/shell_script.dart';
import 'package:mason_logger/mason_logger.dart';

class PendingTasks {
  factory PendingTasks(
    ResolvedHook hook, {
    required Logger logger,
  }) {
    Iterable<(ResolvingTask, TaskRunner)> tasks() sync* {
      for (final (files, command) in hook.commands) {
        final subTaskController = switch (command) {
          ShellScript() => StreamController<int>(),
          _ => null,
        };

        final task = ResolvingTask(
          files: files,
          command: command,
          subTaskController: subTaskController,
          completer: switch (files.length) {
            0 => null,
            _ => Completer<int>(),
          },
        );

        final runner = TaskRunner(
          taskId: task.id,
          task: command,
          files: files.toList(),
          logger: logger,
          onSubTaskCompleted: subTaskController?.add,
        );

        yield (task, runner);
      }
    }

    final mappedTasks = {
      for (final (task, runner) in tasks().toList())
        task.id: (task: task, runner: runner),
    };

    return PendingTasks._(mappedTasks, logger: logger);
  }

  PendingTasks._(
    this._tasks, {
    required this.logger,
  }) {
    _listenToKillSignal();
  }

  final Map<String, ({ResolvingTask task, TaskRunner runner})> _tasks;
  final Logger logger;
  StreamSubscription<ProcessSignal>? _killSubscription;

  bool _wasKilled = false;
  bool get wasKilled => _wasKilled;

  Future<void> _listenToKillSignal() async {
    if (_killSubscription != null) {
      return;
    }

    final stream = Platform.isWindows
        ? ProcessSignal.sigint.watch()
        : StreamGroup.merge(
            [
              ProcessSignal.sigterm.watch(),
              ProcessSignal.sigint.watch(),
            ],
          );

    _killSubscription = stream.listen((signal) async {
      _wasKilled = true;
      killAll();
      _stopKillSignalListener();
    });
  }

  void _stopKillSignalListener() {
    _killSubscription?.cancel().ignore();
    _killSubscription = null;
  }

  List<ResolvingTask> get tasks => List<ResolvingTask>.unmodifiable(
        _tasks.values.map<ResolvingTask>((e) => e.task),
      );

  List<TaskRunner> get runners => List<TaskRunner>.unmodifiable(
        _tasks.values.map<TaskRunner>((e) => e.runner),
      );

  void complete(String taskId, int code) {
    final pending = _tasks[taskId];

    if (pending == null) {
      logger.err('Task $taskId not found');
      return;
    }

    pending.task.code = code;

    if (code != 0) {
      killAll();
    }
  }

  void killAll() {
    for (final task in tasks) {
      task.kill();
    }
  }

  void start() {
    for (final runner in runners) {
      final future = runner.run();

      future.then((code) {
        complete(runner.taskId, code);
      }).ignore();
    }
  }

  Future<void> wait() async {
    try {
      await Future.wait(
        tasks.map((e) => e.future).whereType(),
        eagerError: true,
      );
    } catch (e) {
      logger.delayed('Error: $e');

      killAll();
    }
  }
}
