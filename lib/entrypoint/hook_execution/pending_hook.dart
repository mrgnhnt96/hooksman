import 'dart:async';
import 'dart:io';

import 'package:async/async.dart';
import 'package:hooksman/entrypoint/hook_execution/task_runner.dart';
import 'package:hooksman/models/pending_task.dart';
import 'package:hooksman/models/resolved_hook.dart';
import 'package:mason_logger/mason_logger.dart';

class PendingHook {
  factory PendingHook(
    ResolvedHook hook, {
    required Logger logger,
  }) {
    Iterable<(PendingTask, TaskRunner)> tasks() sync* {
      for (final task in hook.tasks) {
        final subTaskController = StreamController<int>.broadcast();

        final resolving = PendingTask(
          files: task.files,
          resolvedTask: task,
          subTaskController: subTaskController,
          completer: switch (task.files.length) {
            0 => null,
            _ => Completer<int>(),
          },
        );

        final runner = TaskRunner(
          taskId: resolving.id,
          task: resolving,
          files: task.files.toList(),
          logger: logger,
          completeSubTask: (finished) {
            final task = hook.tasksById[finished.id];

            if (task == null) {
              logger.err('Task ${finished.id} not found');
              throw StateError('Task ${finished.id} not found');
            }

            subTaskController.add(task.index);
          },
        );

        yield (resolving, runner);
      }
    }

    final mappedTasks = {
      for (final (task, runner) in tasks().toList())
        task.id: (task: task, runner: runner),
    };

    return PendingHook._(mappedTasks, logger: logger);
  }

  PendingHook._(
    this._tasks, {
    required this.logger,
  }) {
    _listenToKillSignal();
  }

  final Map<String, ({PendingTask task, TaskRunner runner})> _tasks;
  final Logger logger;
  StreamSubscription<ProcessSignal>? _killSubscription;

  bool _wasKilled = false;
  bool get wasKilled => _wasKilled;
  bool get hasCompleted => tasks.every((e) => e.hasCompleted);
  bool get isDead => wasKilled || hasCompleted;

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
      logger.detail('SIGINT detected!');
      if (isDead) {
        exitCode = 1;
        exit(exitCode);
      }

      _wasKilled = true;
      killAll();
      _stopKillSignalListener();
    });
  }

  void _stopKillSignalListener() {
    _killSubscription?.cancel().ignore();
    _killSubscription = null;
  }

  List<PendingTask> get tasks => List<PendingTask>.unmodifiable(
        _tasks.values.map<PendingTask>((e) => e.task),
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
