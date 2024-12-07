import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/commands/register_command.dart';
import 'package:hooksman/models/compiler.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group(RegisterCommand, () {
    late FileSystem fs;
    late GitService git;
    late Logger logger;
    late Compiler compiler;

    setUp(() {
      fs = MemoryFileSystem.test();
      git = _MockGitService();
      logger = _MockLogger();
      compiler = _MockCompiler();
    });

    RegisterCommand cmd() {
      return RegisterCommand(
        fs: fs,
        logger: logger,
        git: git,
        compiler: compiler,
      );
    }

    group('#definedHooks', () {
      test('should return 1 when hooks directory does not exist', () async {
        final command = cmd();
        final (files, code) = command.definedHooks('root');

        expect(files, isEmpty);
        expect(code, 1);

        verify(() => logger.err(any())).called(1);
      });

      test('should return 1 when no hooks are defined', () async {
        fs.directory('root/hooks').createSync(recursive: true);

        final command = cmd();

        final (files, code) = command.definedHooks('root');

        expect(files, isEmpty);
        expect(code, 1);

        verify(() => logger.err(any())).called(1);
      });
    });

    group('#setHooksPath', () {
      test('should return 1 when git.setHooksDir fails', () async {
        when(() => git.setHooksDir()).thenAnswer((_) async => false);

        final command = cmd();
        final result = await command.setHooksPath();

        expect(result, 1);
        verify(() => logger.err('Could not set hooks path')).called(1);
      });

      test('should return 1 and log error when exception is thrown', () async {
        when(() => git.setHooksDir()).thenThrow(Exception('error'));

        final command = cmd();
        final result = await command.setHooksPath();

        expect(result, 1);
        verify(() => logger.err('Could not set hooks path')).called(1);
        verify(() => logger.detail('Exception: error')).called(1);
      });

      test('should return null when git.setHooksDir succeeds', () async {
        when(() => git.setHooksDir()).thenAnswer((_) async => true);

        final command = cmd();
        final result = await command.setHooksPath();

        expect(result, isNull);
      });
    });

    group('#prepareExecutables', () {
      test('should return an empty iterable when no hooks are defined',
          () async {
        final command = cmd();
        final definedHooks = <String>[];
        final hooksDartToolDir = fs.directory('hooks_dart_tool');
        final executablesDir = fs.directory('executables');

        final executables = command.prepareExecutables(
          definedHooks,
          hooksDartToolDir: hooksDartToolDir,
          executablesDir: executablesDir,
        );

        expect(executables, isEmpty);
      });

      group('runs gracefully', () {
        setUp(() {
          when(
            () => compiler.compile(
              file: any(named: 'file'),
              outFile: any(named: 'outFile'),
            ),
          ).thenAnswer(
            (_) => Future.value(ProcessResult(0, 0, '', '')),
          );
        });

        test('should create dart tool dart hooks when hooks are defined',
            () async {
          final command = cmd();

          final definedHooks = [
            'pre-commit.dart',
            'post-commit.dart',
          ];

          final hooksDartToolDir =
              fs.directory(p.join('.dart_tool', 'hooksman'));

          command
              .prepareExecutables(
                definedHooks,
                hooksDartToolDir: hooksDartToolDir,
                executablesDir: fs.directory('executables'),
              )
              .toList();

          expect(hooksDartToolDir.existsSync(), isTrue);
          expect(
            hooksDartToolDir.listSync().map((e) => e.path),
            unorderedEquals([
              p.join('.dart_tool', 'hooksman', 'pre-commit.dart'),
              p.join('.dart_tool', 'hooksman', 'post-commit.dart'),
            ]),
          );
        });

        test('content should import dart hook and execute hook', () async {
          final command = cmd();

          final hooksDartToolDir =
              fs.directory(p.join('.dart_tool', 'hooksman'));

          command.prepareExecutables(
            [p.join('hooks', 'pre_commit.dart')],
            hooksDartToolDir: hooksDartToolDir,
            executablesDir: fs.directory('executables'),
          ).toList();

          final content = await fs
              .file(p.join('.dart_tool', 'hooksman', 'pre_commit.dart'))
              .readAsLines();

          expect(content, [
            "import 'package:hooksman/hooksman.dart';",
            '',
            "import '../../hooks/pre_commit.dart' as hook;",
            '',
            'void main() {',
            "  executeHook('pre-commit', hook.main());",
            '}',
          ]);
        });

        test('should path to dart hook and executable process result',
            () async {
          final command = cmd();

          final definedHooks = [
            'dart_file1.dart',
            'dart_file2.dart',
          ];

          final executables = command
              .prepareExecutables(
                definedHooks,
                hooksDartToolDir: fs.directory('hooks_dart_tool'),
                executablesDir: fs.directory('executables'),
              )
              .toList();

          expect(executables, hasLength(2));
          final [first, second] = executables;
          expect(
            first.executablePath,
            p.join('executables', 'dart-file1'),
          );
          expect(
            second.executablePath,
            p.join('executables', 'dart-file2'),
          );
        });

        test('should use compiler to compile dart hooks', () async {
          final command = cmd();

          final definedHooks = [
            'hook1',
            'hook2',
          ];

          command
              .prepareExecutables(
                definedHooks,
                hooksDartToolDir: fs.directory('hooks_dart_tool'),
                executablesDir: fs.directory('executables'),
              )
              .toList();

          verify(
            () => compiler.compile(
              file: p.join('hooks_dart_tool', 'hook1'),
              outFile: p.join('executables', 'hook1'),
            ),
          ).called(1);

          verify(
            () => compiler.compile(
              file: p.join('hooks_dart_tool', 'hook2'),
              outFile: p.join('executables', 'hook2'),
            ),
          ).called(1);
        });

        test('should delete dart tool git hooks directory', () async {
          final command = cmd();

          final hooksDartToolDir = fs.directory('hooks_dart_tool')
            ..createSync(recursive: true)
            ..childFile('a-file-to-delete').createSync();

          command.prepareExecutables(
            [],
            hooksDartToolDir: hooksDartToolDir,
            executablesDir: fs.directory('executables'),
          ).toList();

          expect(hooksDartToolDir.existsSync(), isFalse);
        });

        test('should create executables directory', () async {
          final command = cmd();

          final executablesDir = fs.directory('executables');

          command.prepareExecutables(
            [],
            hooksDartToolDir: fs.directory('hooks_dart_tool'),
            executablesDir: executablesDir,
          ).toList();

          expect(executablesDir.existsSync(), isTrue);
        });
      });
    });

    group('#copyExecutables', () {
      test('should create the hooks directory when it does not exist',
          () async {
        final command = cmd();
        final code = command.copyExecutables(
          [],
          gitHooksDir: p.join('.git', 'hooks'),
        );

        expect(code, 0);
        expect(fs.directory(p.join('.git', 'hooks')).existsSync(), isTrue);
      });

      test('should copy executables from dart tool to git hooks', () async {
        final command = cmd();

        fs.directory('executables').createSync(recursive: true);

        final executables = [
          fs.file(p.join('.dart_tool', 'hooksman', 'execs', 'pre-commit')),
          fs.file(p.join('.dart_tool', 'hooksman', 'execs', 'pre-push')),
        ];

        for (final exe in executables) {
          exe
            ..createSync(recursive: true)
            ..writeAsStringSync(p.basename(exe.path));
        }

        final hooksDir = fs.directory(p.join('.git', 'hooks'));

        command.copyExecutables(
          executables.map((e) => e.path).toList(),
          gitHooksDir: hooksDir.path,
        );

        final hooks = hooksDir.listSync();

        expect(
          hooks.map((e) => e.path),
          unorderedEquals([
            p.join('.git', 'hooks', 'pre-commit'),
            p.join('.git', 'hooks', 'pre-push'),
          ]),
        );

        for (final hook in hooks) {
          final content = fs.file(hook.path).readAsStringSync();

          expect(content, p.basename(hook.path));
        }
      });

      test('should create hooks dir when it does not exist', () async {
        cmd().copyExecutables(
          [],
          gitHooksDir: p.join('.git', 'hooks'),
        );

        expect(fs.directory(p.join('.git', 'hooks')).existsSync(), isTrue);
      });

      test('should delete hooks dir when it does exist', () async {
        final hooks = fs.directory(p.join('.git', 'hooks'))
          ..createSync(recursive: true)
          ..childFile('a-file-to-delete').createSync();

        cmd().copyExecutables(
          [],
          gitHooksDir: hooks.path,
        );

        expect(hooks.existsSync(), isTrue);
        expect(hooks.childFile('a-file-to-delete').existsSync(), isFalse);
      });

      test('should return 0 when hooks are copied successfully', () async {
        final command = cmd();

        final code = command.copyExecutables(
          [],
          gitHooksDir: p.join('.git', 'hooks'),
        );

        expect(code, 0);
      });
    });

    group('#compile', () {
      test('should run gracefully', () async {
        final command = cmd();

        final result = await command.compile(
          [
            (
              executablePath: 'some/path',
              process: Future.value(ProcessResult(0, 0, '', ''))
            ),
          ],
          (_) {},
        );

        expect(result, isNotNull);
        expect(result, hasLength(1));
        expect(result?.single, 'some/path');
      });

      test('should fail when process is non-zero', () async {
        final command = cmd();

        var failed = false;

        final result = await command.compile([
          (
            executablePath: 'some/path',
            process: Future.value(ProcessResult(0, 1, '', ''))
          ),
        ], (_) {
          failed = true;
        });

        expect(result, isNull);
        expect(failed, isTrue);
      });
    });

    group('#run', () {
      test('should return 1 when root is not found', () async {
        final command = cmd();

        final code = await command.run();

        expect(code, 1);

        verify(() => logger.err(any())).called(1);
      });
    });
  });
}

class _MockGitService extends Mock implements GitService {}

class _MockLogger extends Mock implements Logger {}

class _MockCompiler extends Mock implements Compiler {}
