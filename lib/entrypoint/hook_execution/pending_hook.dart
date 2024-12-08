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
    final killCompleter = Completer<void>();
    final completedTasks = <int>{};

    Iterable<(PendingTask, TaskRunner)> tasks() sync* {
      for (final task in hook.tasks) {
        final resolving = PendingTask(
          files: task.files,
          resolvedTask: task,
          completedTasks: completedTasks,
          isHalted: () => killCompleter.isCompleted,
        );

        final runner = TaskRunner(
          task: resolving,
          logger: logger,
          completeTask: (finished, code) {
            final pending = switch (resolving.taskMap[finished.id]) {
              final task? => task,
              _ when resolving.id == finished.id => resolving,
              _ => null,
            };

            final task = hook.tasksById[finished.id];

            if (task == null || pending == null) {
              logger.delayed(
                'This is not expected, please consider reporting this issue.',
              );
              final errorName = switch ((task, pending)) {
                (null, null) => 'Task and pending task',
                (null, _) => 'Task',
                (_, null) => 'Pending task (index: ${task?.index})',
                _ => 'Unknown',
              };
              throw StateError('$errorName ${finished.id} not found');
            }

            pending.code = code;
            completedTasks.add(task.index);
          },
        );

        yield (resolving, runner);
      }
    }

    final mappedTasks = {
      for (final (task, runner) in [...tasks()])
        task.id: (task: task, runner: runner),
    };

    return PendingHook._(
      mappedTasks,
      logger: logger,
      killCompleter: killCompleter,
      completedTasks: completedTasks,
    );
  }

  PendingHook._(
    this._tasks, {
    required this.logger,
    required Completer<void> killCompleter,
    required Set<int> completedTasks,
  })  : _killCompleter = killCompleter,
        _completedTasks = completedTasks {
    _listenToKillSignal();
  }

  final Map<String, ({PendingTask task, TaskRunner runner})> _tasks;
  final Logger logger;
  final Completer<void> _killCompleter;
  final Set<int> _completedTasks;
  Set<int> get completedTasks => Set<int>.unmodifiable(_completedTasks);
  StreamSubscription<ProcessSignal>? _killSubscription;

  bool _wasKilled = false;
  bool get wasKilled => _wasKilled;
  bool get hasCompleted => topLevelTasks.every((e) => e.hasCompleted);
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
      _killCompleter.complete();
      killAll();
      _stopKillSignalListener();
    });
  }

  void _stopKillSignalListener() {
    _killSubscription?.cancel().ignore();
    _killSubscription = null;
  }

  List<PendingTask> get topLevelTasks => List<PendingTask>.unmodifiable(
        _tasks.values.map<PendingTask>((e) => e.task),
      );

  List<TaskRunner> get runners => List<TaskRunner>.unmodifiable(
        _tasks.values.map<TaskRunner>((e) => e.runner),
      );

  void complete(String taskId, int code) {
    final pending = _tasks[taskId];

    if (pending == null) {
      logger.err('Pending task $taskId not found');
      return;
    }

    pending.task.code = code;

    if (code != 0) {
      killAll();
    }
  }

  void killAll() {
    for (final task in topLevelTasks) {
      task.kill();
    }
  }

  void start() {
    for (final runner in runners) {
      final future = runner.run();

      future.then((code) {
        complete(runner.task.id, code);
      }).ignore();
    }
  }

  Future<void> wait() async {
    try {
      await Future.wait(
        topLevelTasks.map((e) => e.future).whereType(),
        eagerError: true,
      );
    } catch (e) {
      logger.delayed('Error: $e');

      killAll();
    }
  }
}
