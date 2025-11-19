import 'dart:async';

import 'package:glob/glob.dart';
import 'package:hooksman/tasks/hook_task.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

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

    group('#resolveSubTasks', () {
      test('should return return all tasks when files match', () async {
        final task = _TestHookTask(
          tasks: [
            _TestHookTask(id: 'dart', include: [Glob('**.dart')]),
          ],
        );

        final result = task.resolveSubTasks(['lib/main.dart']);

        expect(result, hasLength(1));
        expect(result.first.id, 'dart');
      });

      test('should return return no tasks when files do not match', () async {
        final task = _TestHookTask(
          tasks: [
            _TestHookTask(include: [Glob('**.dart')]),
          ],
        );

        final result = task.resolveSubTasks(['lib/main.md']);

        expect(result, isEmpty);
      });

      test('should return task when some files match', () async {
        final task = _TestHookTask(
          tasks: [
            _TestHookTask(id: 'dart', include: [Glob('**.dart')]),
            _TestHookTask(id: 'md', include: [Glob('**.md')]),
          ],
        );

        final result = task.resolveSubTasks(['lib/main.dart', 'README.md']);

        expect(result, hasLength(2));
        expect(result.first.id, 'dart');
        expect(result.last.id, 'md');
      });

      test(
        'should return task when some files match and some do not',
        () async {
          final task = _TestHookTask(
            tasks: [
              _TestHookTask(id: 'dart', include: [Glob('**.dart')]),
              _TestHookTask(id: 'md', include: [Glob('**.md')]),
            ],
          );

          final result = task.resolveSubTasks([
            'lib/main.dart',
            'lib/utils.dart',
          ]);

          expect(result, hasLength(1));
          expect(result.first.id, 'dart');
        },
      );
    });
  });
}

class _TestHookTask extends HookTask {
  _TestHookTask({
    super.include = const [],
    this.tasks = const [],
    this.id = '',
  });
  _TestHookTask.always()
    : tasks = const [],
      id = const Uuid().v4(),
      super.always();

  final List<HookTask> tasks;

  @override
  final String id;

  @override
  List<HookTask> subTasks(Iterable<String> filePaths) => tasks;

  @override
  String? get name => '';

  @override
  FutureOr<int> run(
    List<String> filePaths, {
    required void Function(String? string) print,
    required void Function(HookTask p1, int p2) completeTask,
    required void Function(HookTask p1) startTask,
    required String? workingDirectory,
  }) {
    throw UnimplementedError();
  }
}
