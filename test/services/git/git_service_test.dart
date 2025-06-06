// ignore_for_file: unused_element_parameter
import 'dart:io' as io;

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:hooksman/utils/process/process.dart';
import 'package:hooksman/utils/process/process_details.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

void main() {
  group(GitService, () {
    late GitService git;
    late Logger logger;
    late FileSystem fs;
    late Process process;

    setUpAll(() {
      registerFallbackValue(io.ProcessStartMode.normal);
    });

    setUp(() {
      logger = _MockLogger();
      fs = MemoryFileSystem.test();
      process = _MockProcess();

      when(
        () => process.start(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
          mode: any(named: 'mode'),
        ),
      ).thenAnswer(
        (_) async => ProcessDetails(
          stdout: Stream.value([]),
          stderr: Stream.value([]),
          exitCode: Future.value(0),
        ),
      );

      when(
        () => process.sync(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenReturn(
        const ProcessDetailsSync(
          stdout: '',
          stderr: '',
          exitCode: 0,
        ),
      );
      when(
        () => process.run(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenAnswer(
        (_) async => const ProcessDetailsSync(
          stdout: '',
          stderr: '',
          exitCode: 0,
        ),
      );

      git = GitService(
        logger: logger,
        fs: fs,
        debug: true,
        process: process,
      );
    });

    void stubSync(ProcessDetailsSync details) {
      when(
        () => process.sync(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenReturn(details);
    }

    void stubRun(ProcessDetailsSync details) {
      when(
        () => process.run(
          any(),
          any(),
          workingDirectory: any(named: 'workingDirectory'),
          environment: any(named: 'environment'),
          includeParentEnvironment: any(named: 'includeParentEnvironment'),
          runInShell: any(named: 'runInShell'),
        ),
      ).thenAnswer((_) async => details);
    }

    void stubGitDir() {
      stubSync(
        const ProcessDetailsSync(
          stdout: '''
.git

''',
          stderr: '',
          exitCode: 0,
        ),
      );
    }

    setUp(stubGitDir);

    group('#gitDir', () {
      test('returns the git directory', () {
        final gitDir = git.gitDir;

        expect(gitDir, '.git');

        verify(
          () => process.sync(
            'git',
            ['rev-parse', '--git-dir'],
          ),
        ).called(1);
      });
    });

    group('#setHooksDir', () {
      test('sets the hooks directory', () async {
        await git.setHooksDir();

        verify(
          () => process.run(
            'git',
            ['config', '--local', 'core.hooksPath', '.git/hooks'],
          ),
        ).called(1);
      });

      test('returns false if the process fails', () async {
        stubRun(
          const ProcessDetailsSync(
            stdout: '',
            stderr: '',
            exitCode: 1,
          ),
        );

        final result = await git.setHooksDir();

        expect(result, false);
      });
    });

    group('#stagedFiles', () {
      test('returns the staged files', () async {
        stubRun(
          const ProcessDetailsSync(
            stdout: '''
other.dart 
''',
            stderr: '',
            exitCode: 0,
          ),
        );

        final files = await git.stagedFiles();

        expect(files, [
          'other.dart',
        ]);

        verify(
          () => process.run(
            'git',
            [
              'diff',
              'HEAD',
              '--staged',
              '--diff-filter=ACMR',
              '--name-only',
              '-z',
            ],
          ),
        ).called(1);
      });
    });

    group('#nonStagedFiles', () {
      test('returns the non-staged files', () async {
        stubRun(
          const ProcessDetailsSync(
            stdout: '''
bin/hooksman.dart lib/entrypoint/execute_hook.dart lib/services/git/git_service.dart todo.md 
''',
            stderr: '',
            exitCode: 0,
          ),
        );

        final files = await git.nonStagedFiles();

        expect(files, [
          'bin/hooksman.dart',
          'lib/entrypoint/execute_hook.dart',
          'lib/services/git/git_service.dart',
          'todo.md',
        ]);

        verify(
          () => process.run(
            'git',
            [
              'diff',
              '--diff-filter=ACMR',
              '--name-only',
              '-z',
            ],
          ),
        ).called(1);
      });
    });

    group('#deletedFiles', () {
      test('returns the deleted files', () async {
        stubRun(
          const ProcessDetailsSync(
            stdout: '''
fake.dart other.dart 
''',
            stderr: '',
            exitCode: 0,
          ),
        );

        final files = await git.deletedFiles();

        expect(files, [
          'fake.dart',
          'other.dart',
        ]);
      });
    });

    group('#partiallyStagedFiles', () {
      test('should return empty when no files are both staged and unstaged',
          () async {
        stubRun(
          const ProcessDetailsSync(
            stdout: '''
 M bin/hooksman.dart  D fake.dart  M lib/entrypoint/execute_hook.dart  M lib/services/git/git_service.dart A  other.dart  M todo.md ?? lib/utils/process/ ?? test/services/ 
''',
            stderr: '',
            exitCode: 0,
          ),
        );

        final files = await git.partiallyStagedFiles();

        expect(files, isEmpty);
      });

      test('should return the partially staged files', () async {
        stubRun(
          const ProcessDetailsSync(
            stdout: '''
 M bin/hooksman.dart  D fake.dart  M lib/entrypoint/execute_hook.dart  M lib/services/git/git_service.dart AM other.dart  M todo.md ?? lib/utils/process/ ?? test/services/ 
''',
            stderr: '',
            exitCode: 0,
          ),
        );

        final files = await git.partiallyStagedFiles();

        expect(files, [
          'other.dart',
        ]);
      });
    });

    group('#add', () {
      test('adds the files', () async {
        await git.add(['file1', 'file2']);

        verify(
          () => process.run('git', ['add', '--', 'file1', 'file2']),
        ).called(1);
      });
    });

    group('#applyModifications', () {
      void stub({
        List<String> nonStagedFiles = const [],
        List<String> deletedFiles = const [],
      }) {
        final calls = [
          // non staged files
          ProcessDetailsSync(
            stdout: nonStagedFiles.join('\x00'),
            stderr: '',
            exitCode: 0,
          ),
          // deleted files
          ProcessDetailsSync(
            stdout: deletedFiles.join('\x00'),
            stderr: '',
            exitCode: 0,
          ),
        ];

        when(
          () => process.run(
            any(),
            any(),
            workingDirectory: any(named: 'workingDirectory'),
            environment: any(named: 'environment'),
            includeParentEnvironment: any(named: 'includeParentEnvironment'),
            runInShell: any(named: 'runInShell'),
          ),
        ).thenAnswer((_) async {
          if (calls.isEmpty) {
            return const ProcessDetailsSync(
              stdout: '',
              stderr: '',
              exitCode: 0,
            );
          }

          return calls.removeAt(0);
        });
      }

      test('should not add any files if there are no modifications', () async {
        stub(
          nonStagedFiles: const ['file1'],
          deletedFiles: const ['file2'],
        );

        await git.applyModifications(['file1', 'file2']);

        final data = verify(
          () => process.run(
            any(),
            captureAny(),
          ),
        ).captured;

        for (final captured in data) {
          final [arg, ...] = captured as List<dynamic>;
          expect(arg, isNot('add'));
        }
      });

      test('should add the files that are modified', () async {
        stub(
          nonStagedFiles: const ['file1'],
          deletedFiles: const ['file2'],
        );

        await git.applyModifications([]);

        final data = verify(
          () => process.run(
            any(),
            captureAny(),
          ),
        ).captured
          ..removeWhere((e) => (e as List).first != 'add');

        expect(data.first, ['add', '--', 'file1', 'file2']);
      });
    });
  });
}

class _MockLogger extends Mock implements Logger {}

class _MockProcess extends Mock implements Process {}
