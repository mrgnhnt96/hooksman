import 'dart:async';
import 'dart:io';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/commands/register_command.dart';
import 'package:hooksman/models/compiler.dart';
import 'package:hooksman/models/defined_hook.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  group(RegisterCommand, () {
    late FileSystem fs;
    late GitService git;
    late Logger logger;
    late Compiler compiler;
    late RegisterCommand cmd;

    setUp(() {
      fs = MemoryFileSystem.test();
      git = _MockGitService();
      logger = _MockLogger();
      compiler = _MockCompiler();

      cmd = const RegisterCommand();
    });

    void test(String description, FutureOr<void> Function() fn) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        logger: () => logger,
        compiler: () => compiler,
        git: () => git,
      );
    }

    group('#definedHooks', () {
      test('should return 1 when hooks directory does not exist', () async {
        final (files, code) = cmd.definedHooks('root');

        expect(files, isEmpty);
        expect(code, 1);

        verify(() => logger.err(any())).called(1);
      });

      test('should return 1 when no hooks are defined', () async {
        fs.directory('root/hooks').createSync(recursive: true);

        final (files, code) = cmd.definedHooks('root');

        expect(files, isEmpty);
        expect(code, 1);

        verify(() => logger.err(any())).called(1);
      });
    });

    group('#setHooksPath', () {
      test('should return 1 when git.setHooksDir fails', () async {
        when(() => git.setHooksDir()).thenAnswer((_) async => false);

        final result = await cmd.setHooksPath();

        expect(result, 1);
        verify(() => logger.err('Could not set hooks path')).called(1);
      });

      test('should return 1 and log error when exception is thrown', () async {
        when(() => git.setHooksDir()).thenThrow(Exception('error'));

        final result = await cmd.setHooksPath();

        expect(result, 1);
        verify(() => logger.err('Could not set hooks path')).called(1);
        verify(() => logger.detail('Exception: error')).called(1);
      });

      test('should return null when git.setHooksDir succeeds', () async {
        when(() => git.setHooksDir()).thenAnswer((_) async => true);

        final result = await cmd.setHooksPath();

        expect(result, isNull);
      });
    });

    group('#prepareExecutables', () {
      test('should return an empty iterable when no hooks are defined',
          () async {
        final definedHooks = <DefinedHook>[];
        final hooksDartToolDir = fs.directory('hooks_dart_tool');
        final executablesDir = fs.directory('executables');

        final executables = cmd.prepareExecutables(
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

          when(
            () => compiler.prepareShellExecutable(
              file: any(named: 'file'),
              outFile: any(named: 'outFile'),
            ),
          ).thenAnswer(
            (_) => Future.value(ProcessResult(0, 0, '', '')),
          );
        });

        test('should create dart tool dart hooks when hooks are defined',
            () async {
          final definedHooks = [
            const DefinedHook('pre-commit.dart'),
            const DefinedHook('post-commit.dart'),
          ];

          final hooksDartToolDir =
              fs.directory(fs.path.join('.dart_tool', 'hooksman'));

          cmd
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
              fs.path.join('.dart_tool', 'hooksman', 'pre-commit.dart'),
              fs.path.join('.dart_tool', 'hooksman', 'post-commit.dart'),
            ]),
          );
        });

        test('content should import dart hook and execute hook', () async {
          final hooksDartToolDir =
              fs.directory(fs.path.join('.dart_tool', 'hooksman'));

          cmd.prepareExecutables(
            [
              DefinedHook(fs.path.join('hooks', 'pre_commit.dart')),
            ],
            hooksDartToolDir: hooksDartToolDir,
            executablesDir: fs.directory('executables'),
          ).toList();

          final content = await fs
              .file(fs.path.join('.dart_tool', 'hooksman', 'pre_commit.dart'))
              .readAsLines();

          expect(content, [
            "import 'package:hooksman/hooksman.dart';",
            '',
            "import '../../hooks/pre_commit.dart' as hook;",
            '',
            'void main(List<String> args) {',
            "  executeHook('pre-commit', hook.main(), args);",
            '}',
          ]);
        });

        test('should path to dart hook and executable process result',
            () async {
          final definedHooks = [
            const DefinedHook('dart_file1.dart'),
            const DefinedHook('dart_file2.dart'),
          ];

          final executables = cmd
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
            fs.path.join('executables', 'dart-file1'),
          );
          expect(
            second.executablePath,
            fs.path.join('executables', 'dart-file2'),
          );
        });

        test('should use compiler to compile dart hooks', () async {
          final definedHooks = [
            const DefinedHook('hook1.dart'),
            const DefinedHook('hook2.dart'),
          ];

          cmd
              .prepareExecutables(
                definedHooks,
                hooksDartToolDir: fs.directory('hooks_dart_tool'),
                executablesDir: fs.directory('executables'),
              )
              .toList();

          verify(
            () => compiler.compile(
              file: fs.path.join('hooks_dart_tool', 'hook1.dart'),
              outFile: fs.path.join('executables', 'hook1'),
            ),
          ).called(1);

          verify(
            () => compiler.compile(
              file: fs.path.join('hooks_dart_tool', 'hook2.dart'),
              outFile: fs.path.join('executables', 'hook2'),
            ),
          ).called(1);
        });

        test('should delete dart tool git hooks directory', () async {
          final hooksDartToolDir = fs.directory('hooks_dart_tool')
            ..createSync(recursive: true)
            ..childFile('a-file-to-delete').createSync();

          cmd.prepareExecutables(
            [],
            hooksDartToolDir: hooksDartToolDir,
            executablesDir: fs.directory('executables'),
          ).toList();

          expect(hooksDartToolDir.existsSync(), isFalse);
        });

        test('should create executables directory', () async {
          final executablesDir = fs.directory('executables');

          cmd.prepareExecutables(
            [],
            hooksDartToolDir: fs.directory('hooks_dart_tool'),
            executablesDir: executablesDir,
          ).toList();

          expect(executablesDir.existsSync(), isTrue);
        });

        test('should prepare shell hooks when hooks are defined', () async {
          final definedHooks = [
            const DefinedHook('pre-commit.sh'),
            const DefinedHook('post-commit.sh'),
          ];

          final hooksDartToolDir =
              fs.directory(fs.path.join('.dart_tool', 'hooksman'));

          final results = cmd
              .prepareExecutables(
                definedHooks,
                hooksDartToolDir: hooksDartToolDir,
                executablesDir: fs.directory('executables'),
              )
              .toList();

          expect(results, hasLength(2));
          expect(
            results.map((e) => e.executablePath),
            unorderedEquals([
              fs.path.join('executables', 'pre-commit'),
              fs.path.join('executables', 'post-commit'),
            ]),
          );

          verify(
            () => compiler.prepareShellExecutable(
              file: 'pre-commit.sh',
              outFile: fs.path.joinAll(['executables', 'pre-commit']),
            ),
          ).called(1);

          verify(
            () => compiler.prepareShellExecutable(
              file: 'post-commit.sh',
              outFile: fs.path.joinAll(['executables', 'post-commit']),
            ),
          ).called(1);
        });

        test('should copy shell hooks to executables directory', () async {
          final definedHooks = [
            const DefinedHook('pre-commit.sh'),
            const DefinedHook('post-commit.sh'),
          ];

          final hooksDartToolDir =
              fs.directory(fs.path.join('.dart_tool', 'hooksman'));

          final executables = cmd
              .prepareExecutables(
                definedHooks,
                hooksDartToolDir: hooksDartToolDir,
                executablesDir: fs.directory('executables'),
              )
              .toList();

          expect(executables, hasLength(2));
          final [first, second] = executables;
          expect(
            first.executablePath,
            fs.path.join('executables', 'pre-commit'),
          );
          expect(
            second.executablePath,
            fs.path.join('executables', 'post-commit'),
          );
        });
      });
    });

    group('#copyExecutables', () {
      test('should create the hooks directory when it does not exist',
          () async {
        final code = cmd.copyExecutables(
          [],
          gitHooksDir: fs.path.join('.git', 'hooks'),
        );

        expect(code, 0);
        expect(
          fs.directory(fs.path.join('.git', 'hooks')).existsSync(),
          isTrue,
        );
      });

      test('should copy executables from dart tool to git hooks', () async {
        fs.directory('executables').createSync(recursive: true);

        final executables = [
          fs.file(
            fs.path.join('.dart_tool', 'hooksman', 'execs', 'pre-commit'),
          ),
          fs.file(fs.path.join('.dart_tool', 'hooksman', 'execs', 'pre-push')),
        ];

        for (final exe in executables) {
          exe
            ..createSync(recursive: true)
            ..writeAsStringSync(fs.path.basename(exe.path));
        }

        final hooksDir = fs.directory(fs.path.join('.git', 'hooks'));

        cmd.copyExecutables(
          executables.map((e) => e.path).toList(),
          gitHooksDir: hooksDir.path,
        );

        final hooks = hooksDir.listSync();

        expect(
          hooks.map((e) => e.path),
          unorderedEquals([
            fs.path.join('.git', 'hooks', 'pre-commit'),
            fs.path.join('.git', 'hooks', 'pre-push'),
          ]),
        );

        for (final hook in hooks) {
          final content = fs.file(hook.path).readAsStringSync();

          expect(content, fs.path.basename(hook.path));
        }
      });

      test('should create hooks dir when it does not exist', () async {
        cmd.copyExecutables(
          [],
          gitHooksDir: fs.path.join('.git', 'hooks'),
        );

        expect(
          fs.directory(fs.path.join('.git', 'hooks')).existsSync(),
          isTrue,
        );
      });

      test('should delete hooks dir when it does exist', () async {
        final hooks = fs.directory(fs.path.join('.git', 'hooks'))
          ..createSync(recursive: true)
          ..childFile('a-file-to-delete').createSync();

        cmd.copyExecutables(
          [],
          gitHooksDir: hooks.path,
        );

        expect(hooks.existsSync(), isTrue);
        expect(hooks.childFile('a-file-to-delete').existsSync(), isFalse);
      });

      test('should return 0 when hooks are copied successfully', () async {
        final code = cmd.copyExecutables(
          [],
          gitHooksDir: fs.path.join('.git', 'hooks'),
        );

        expect(code, 0);
      });
    });

    group('#compile', () {
      test('should run gracefully', () async {
        final result = await cmd.compile(
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
        var failed = false;

        final result = await cmd.compile([
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
        final code = await cmd.run();

        expect(code, 1);

        verify(() => logger.err(any())).called(1);
      });
    });
  });
}

class _MockGitService extends Mock implements GitService {}

class _MockLogger extends Mock implements Logger {}

class _MockCompiler extends Mock implements Compiler {}
