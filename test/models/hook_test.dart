import 'dart:async';

import 'package:hooksman/models/hook.dart';
import 'package:hooksman/models/hook_task.dart';
import 'package:test/test.dart';

void main() {
  group(Hook, () {
    group('#resolve', () {
      test('resolves multiple commands', () {
        final hook = Hook(
          tasks: [
            _TestTask(
              name: 'command1',
              include: [RegExp(r'.*\.dart')],
            ),
            _TestTask(
              name: 'command2',
              include: [RegExp(r'.*\.md')],
            ),
          ],
        );

        final result = hook.resolve(['lib/main.dart', 'README.md']);

        expect(result.files, ['lib/main.dart', 'README.md']);
        expect(result.tasks, hasLength(2));

        final resolved1 = result.tasks[0];
        expect(resolved1.files, ['lib/main.dart']);
        expect(resolved1.original, hook.tasks[0]);

        final resolved2 = result.tasks[1];
        expect(resolved2.files, ['README.md']);
        expect(resolved2.original, hook.tasks[1]);
      });

      test('resolves commands when no files match', () {
        final hook = Hook(
          tasks: [
            _TestTask(
              name: 'command1',
              include: [RegExp(r'.*\.dart')],
            ),
          ],
        );

        final result = hook.resolve(['README.md']);

        expect(result.files, ['README.md']);
        expect(result.tasks, hasLength(1));
        final resolved = result.tasks.single;
        expect(resolved.files, isEmpty);
        expect(resolved.original, hook.tasks.first);
      });

      test('resolves commands with multiple matching files', () {
        final hook = Hook(
          tasks: [
            _TestTask(
              name: 'command1',
              include: [RegExp(r'.*\.dart')],
            ),
          ],
        );

        final result = hook.resolve(['lib/main.dart', 'lib/utils.dart']);

        expect(result.files, ['lib/main.dart', 'lib/utils.dart']);
        expect(result.tasks, hasLength(1));

        final resolved = result.tasks.single;
        expect(resolved.files, ['lib/main.dart', 'lib/utils.dart']);
        expect(resolved.original, hook.tasks.first);
      });

      test('resolves commands with multiple patterns', () {
        final hook = Hook(
          tasks: [
            _TestTask(
              name: 'command1',
              include: [RegExp(r'.*\.dart'), RegExp(r'.*\.md')],
            ),
          ],
        );

        final result = hook.resolve(['lib/main.dart', 'README.md']);

        expect(result.files, ['lib/main.dart', 'README.md']);
        expect(result.tasks, hasLength(1));

        final resolved = result.tasks.single;
        expect(resolved.files, ['lib/main.dart', 'README.md']);
        expect(resolved.original, hook.tasks.first);
      });

      test('excludes files matching exclude patterns', () {
        final hook = Hook(
          tasks: [
            _TestTask(
              name: 'command1',
              include: [RegExp(r'.*\.dart')],
              exclude: [RegExp(r'.*\.g\.dart')],
            ),
          ],
        );

        final result = hook.resolve(['lib/main.dart', 'lib/main.g.dart']);

        expect(result.files, ['lib/main.dart', 'lib/main.g.dart']);
        expect(result.tasks, hasLength(1));

        final resolved = result.tasks.single;
        expect(resolved.files, ['lib/main.dart']);
        expect(resolved.original, hook.tasks.first);
      });

      test('excludes files matching multiple exclude patterns', () {
        final hook = Hook(
          tasks: [
            _TestTask(
              name: 'command1',
              include: [RegExp(r'.*\.dart')],
              exclude: [
                RegExp(r'.*\.g\.dart'),
                RegExp(r'.*\.freezed\.dart'),
              ],
            ),
          ],
        );

        final result = hook.resolve(
          ['lib/main.dart', 'lib/main.g.dart', 'lib/main.freezed.dart'],
        );

        expect(
          result.files,
          ['lib/main.dart', 'lib/main.g.dart', 'lib/main.freezed.dart'],
        );
        expect(result.tasks, hasLength(1));

        final resolved = result.tasks.single;
        expect(resolved.files, ['lib/main.dart']);
        expect(resolved.original, hook.tasks.first);
      });
    });
  });
}

class _TestTask extends HookTask {
  _TestTask({
    required this.name,
    required super.include,
    super.exclude = const [],
  });

  @override
  final String? name;

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String? p1) print,
    required void Function(int p1) completeTask,
  }) {
    throw UnimplementedError();
  }
}
