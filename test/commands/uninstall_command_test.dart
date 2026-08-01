import 'dart:async';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/commands/uninstall_command.dart';
import 'package:hooksman/models/args.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../utils/test_scoped.dart';

void main() {
  group(UninstallCommand, () {
    late FileSystem fs;
    late GitService git;
    late Logger logger;
    late UninstallCommand cmd;
    late Args args;

    setUp(() {
      fs = MemoryFileSystem.test();
      git = _MockGitService();
      logger = _MockLogger();
      args = const Args();
      cmd = const UninstallCommand();

      final root = fs.directory('/project')..createSync();
      fs.currentDirectory = root;
      root.childFile('pubspec.yaml').createSync();
    });

    void test(
      String description,
      FutureOr<void> Function() fn, {
      Args Function()? argsOverride,
    }) {
      testScoped(
        description,
        fn,
        fileSystem: () => fs,
        logger: () => logger,
        git: () => git,
        args: argsOverride ?? () => args,
      );
    }

    test('unsetHooksDir called; returns 0 on success', () async {
      when(() => git.unsetHooksDir()).thenAnswer((_) async => true);

      final code = await cmd.run();

      expect(code, 0);
      verify(() => git.unsetHooksDir()).called(1);
    });

    test('returns 1 when unset fails', () async {
      when(() => git.unsetHooksDir()).thenAnswer((_) async => false);

      final code = await cmd.run();

      expect(code, 1);
      verify(() => git.unsetHooksDir()).called(1);
    });

    test(
      'deletes shims under hooks/_ but keeps .gitignore and README.md',
      () async {
        when(() => git.unsetHooksDir()).thenAnswer((_) async => true);

        final managed = fs.directory('/project/hooks/_')
          ..createSync(recursive: true);
        managed.childFile('.gitignore').writeAsStringSync('*\n');
        managed.childFile('README.md').writeAsStringSync('# keep\n');
        managed.childFile('pre-commit').writeAsStringSync('shim');
        managed.childFile('pre-push').writeAsStringSync('shim');

        final code = await cmd.run();

        expect(code, 0);
        expect(managed.childFile('.gitignore').existsSync(), isTrue);
        expect(managed.childFile('README.md').existsSync(), isTrue);
        expect(managed.childFile('pre-commit').existsSync(), isFalse);
        expect(managed.childFile('pre-push').existsSync(), isFalse);
      },
    );

    test('leaves hooks/*.dart sources untouched', () async {
      when(() => git.unsetHooksDir()).thenAnswer((_) async => true);

      final hooks = fs.directory('/project/hooks')..createSync(recursive: true);
      hooks.childFile('pre_commit.dart').writeAsStringSync('Hook main() {}');
      hooks.childDirectory('_').createSync();
      hooks.childDirectory('_').childFile('pre-commit').writeAsStringSync('x');

      final code = await cmd.run();

      expect(code, 0);
      expect(hooks.childFile('pre_commit.dart').existsSync(), isTrue);
      expect(
        hooks.childFile('pre_commit.dart').readAsStringSync(),
        'Hook main() {}',
      );
      expect(
        hooks.childDirectory('_').childFile('pre-commit').existsSync(),
        isFalse,
      );
    });

    test('--help returns 0', () async {
      final code = await cmd.run();

      expect(code, 0);
      verify(() => logger.write(any())).called(1);
      verifyNever(() => git.unsetHooksDir());
    }, argsOverride: () => const Args(args: {'help': true}));
  });
}

class _MockGitService extends Mock implements GitService {}

class _MockLogger extends Mock implements Logger {}
