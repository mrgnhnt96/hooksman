import 'dart:async';

import 'package:hooksman/tasks/hook_task.dart';
import 'package:test/test.dart';

void main() {
  group(HookTask, () {
    group('#shouldAlwaysRun', () {
      test('should return true when task is always', () {
        final task = _TestHookTask.always();

        expect(task.shouldAlwaysRun, isTrue);
      });

      test('should return true when sub task is set to always', () {
        final task = _TestHookTask(tasks: [_TestHookTask.always()]);

        expect(task.shouldAlwaysRun, isTrue);
      });

      test('should return true when sub sub task is set to always', () {
        final task = _TestHookTask(
          tasks: [
            _TestHookTask(tasks: [_TestHookTask.always()]),
          ],
        );

        expect(task.shouldAlwaysRun, isTrue);
      });
    });
  });
}

class _TestHookTask extends HookTask {
  _TestHookTask({super.include = const [], this.tasks = const []});
  _TestHookTask.always()
      : tasks = const [],
        super.always();

  final List<HookTask> tasks;

  @override
  List<HookTask> getSubTasks(Iterable<String> filePaths) => tasks;

  @override
  String? get name => '';

  @override
  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String? string) print,
    required void Function(HookTask p1, int p2) completeTask,
    required void Function(HookTask p1) startTask,
  }) {
    throw UnimplementedError();
  }
}
