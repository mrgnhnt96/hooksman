import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/models/hook.dart';
import 'package:hooksman/models/hook_task.dart';
import 'package:hooksman/models/resolver.dart';
import 'package:test/test.dart';

void main() {
  group(Resolver, () {
    late FileSystem fs;

    setUp(() {
      fs = MemoryFileSystem.test();
    });

    Resolver resolver(Hook hook) {
      return Resolver(hook: hook, fs: fs);
    }

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

      final result = resolver(hook).resolve(['lib/main.dart', 'README.md']);

      expect(result.files, ['lib/main.dart', 'README.md']);
      expect(result.tasks, hasLength(2));

      final (files1, command1) = result.tasks[0];
      expect(files1, ['lib/main.dart']);
      expect(command1, hook.tasks[0]);

      final (files2, command2) = result.tasks[1];
      expect(files2, ['README.md']);
      expect(command2, hook.tasks[1]);
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

      final result = resolver(hook).resolve(['README.md']);

      expect(result.files, ['README.md']);
      expect(result.tasks, hasLength(1));
      final (files, command) = result.tasks.single;
      expect(files, isEmpty);
      expect(command, hook.tasks.first);
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

      final result =
          resolver(hook).resolve(['lib/main.dart', 'lib/utils.dart']);

      expect(result.files, ['lib/main.dart', 'lib/utils.dart']);
      expect(result.tasks, hasLength(1));

      final (files, command) = result.tasks.single;
      expect(files, ['lib/main.dart', 'lib/utils.dart']);
      expect(command, hook.tasks.first);
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

      final result = resolver(hook).resolve(['lib/main.dart', 'README.md']);

      expect(result.files, ['lib/main.dart', 'README.md']);
      expect(result.tasks, hasLength(1));

      final (files, command) = result.tasks.single;
      expect(files, ['lib/main.dart', 'README.md']);
      expect(command, hook.tasks.first);
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

      final result =
          resolver(hook).resolve(['lib/main.dart', 'lib/main.g.dart']);

      expect(result.files, ['lib/main.dart', 'lib/main.g.dart']);
      expect(result.tasks, hasLength(1));

      final (files, command) = result.tasks.single;
      expect(files, ['lib/main.dart']);
      expect(command, hook.tasks.first);
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

      final result = resolver(hook).resolve(
        ['lib/main.dart', 'lib/main.g.dart', 'lib/main.freezed.dart'],
      );

      expect(
        result.files,
        ['lib/main.dart', 'lib/main.g.dart', 'lib/main.freezed.dart'],
      );
      expect(result.tasks, hasLength(1));

      final (files, command) = result.tasks.single;
      expect(files, ['lib/main.dart']);
      expect(command, hook.tasks.first);
    });
  });
}

class _TestTask extends HookTask {
  const _TestTask({
    required String name,
    required List<RegExp> include,
    List<RegExp> exclude = const [],
  }) : super(name: name, include: include, exclude: exclude);

  @override
  FutureOr<int> run(
    List<String> files, {
    required void Function(String? p1) print,
    required void Function(int p1) completeSubTask,
  }) {
    throw UnimplementedError();
  }

  @override
  TaskLabel label(Iterable<String> files) {
    throw UnimplementedError();
  }
}
