import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/hook_task.dart';
import 'package:git_hooks/models/resolver.dart';
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
        commands: [
          HookTask(
            name: 'command1',
            include: [RegExp(r'.*\.dart')],
          ),
          HookTask(
            name: 'command2',
            include: [RegExp(r'.*\.md')],
          ),
        ],
      );

      final result = resolver(hook).resolve(['lib/main.dart', 'README.md']);

      expect(result.files, ['lib/main.dart', 'README.md']);
      expect(result.commands, hasLength(2));

      final (files1, command1) = result.commands[0];
      expect(files1, ['lib/main.dart']);
      expect(command1, hook.commands[0]);

      final (files2, command2) = result.commands[1];
      expect(files2, ['README.md']);
      expect(command2, hook.commands[1]);
    });

    test('resolves commands when no files match', () {
      final hook = Hook(
        commands: [
          HookTask(
            name: 'command1',
            include: [RegExp(r'.*\.dart')],
          ),
        ],
      );

      final result = resolver(hook).resolve(['README.md']);

      expect(result.files, ['README.md']);
      expect(result.commands, hasLength(1));
      final (files, command) = result.commands.single;
      expect(files, isEmpty);
      expect(command, hook.commands.first);
    });

    test('resolves commands with multiple matching files', () {
      final hook = Hook(
        commands: [
          HookTask(
            name: 'command1',
            include: [RegExp(r'.*\.dart')],
          ),
        ],
      );

      final result =
          resolver(hook).resolve(['lib/main.dart', 'lib/utils.dart']);

      expect(result.files, ['lib/main.dart', 'lib/utils.dart']);
      expect(result.commands, hasLength(1));

      final (files, command) = result.commands.single;
      expect(files, ['lib/main.dart', 'lib/utils.dart']);
      expect(command, hook.commands.first);
    });

    test('resolves commands with multiple patterns', () {
      final hook = Hook(
        commands: [
          HookTask(
            name: 'command1',
            include: [RegExp(r'.*\.dart'), RegExp(r'.*\.md')],
          ),
        ],
      );

      final result = resolver(hook).resolve(['lib/main.dart', 'README.md']);

      expect(result.files, ['lib/main.dart', 'README.md']);
      expect(result.commands, hasLength(1));

      final (files, command) = result.commands.single;
      expect(files, ['lib/main.dart', 'README.md']);
      expect(command, hook.commands.first);
    });

    test('excludes files matching exclude patterns', () {
      final hook = Hook(
        commands: [
          HookTask(
            name: 'command1',
            include: [RegExp(r'.*\.dart')],
            exclude: [RegExp(r'.*\.g\.dart')],
          ),
        ],
      );

      final result =
          resolver(hook).resolve(['lib/main.dart', 'lib/main.g.dart']);

      expect(result.files, ['lib/main.dart', 'lib/main.g.dart']);
      expect(result.commands, hasLength(1));

      final (files, command) = result.commands.single;
      expect(files, ['lib/main.dart']);
      expect(command, hook.commands.first);
    });

    test('excludes files matching multiple exclude patterns', () {
      final hook = Hook(
        commands: [
          HookTask(
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
      expect(result.commands, hasLength(1));

      final (files, command) = result.commands.single;
      expect(files, ['lib/main.dart']);
      expect(command, hook.commands.first);
    });
  });
}
