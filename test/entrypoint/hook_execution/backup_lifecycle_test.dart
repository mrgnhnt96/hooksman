@Timeout(Duration(minutes: 2))
library;

import 'dart:io';

import 'package:hooksman/entrypoint/hook_execution/hook_executor.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:hooksman/tasks/shell_task.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

/// Verifies which way [HookExecutor.releaseBackup] decides to go, against a
/// real repository: roll back on anything but a clean success, and never throw
/// away the snapshot while it is the only copy of the user's work.
void main() {
  group('backup lifecycle', () {
    late Directory repo;
    late GitService git;

    String run(String executable, List<String> args, {bool allowFail = false}) {
      final result = Process.runSync(
        executable,
        args,
        workingDirectory: repo.path,
      );

      if (!allowFail && result.exitCode != 0) {
        fail(
          '`$executable ${args.join(' ')}` failed (${result.exitCode})\n'
          '${result.stdout}\n${result.stderr}',
        );
      }

      return result.stdout.toString().trim();
    }

    void write(String path, String contents) {
      File('${repo.path}/$path')
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    String? read(String path) {
      final file = File('${repo.path}/$path');
      return file.existsSync() ? file.readAsStringSync() : null;
    }

    bool backupRefExists() => run('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      GitService.backupRef,
    ], allowFail: true).isNotEmpty;

    HookExecutor executorFor(Hook hook) =>
        HookExecutor(hook, hookName: 'pre-commit');

    Hook hookWith({bool backup = true}) => PreCommitHook(
      backup: backup,
      tasks: [
        ShellTask.always(name: 'noop', commands: (_) => const ['true']),
      ],
    );

    setUp(() {
      repo = Directory.systemTemp.createTempSync('hooksman_lifecycle_');
      git = GitService(workingDirectory: repo.path);

      run('git', ['init', '--quiet', '--initial-branch=main', '.']);
      run('git', ['config', 'user.email', 'test@example.com']);
      run('git', ['config', 'user.name', 'Test']);
      run('git', ['config', 'commit.gpgsign', 'false']);

      write('a.dart', 'orig\n');
      run('git', ['add', '-A']);
      run('git', ['commit', '--quiet', '-m', 'init']);
    });

    tearDown(() {
      try {
        repo.deleteSync(recursive: true);
      } catch (_) {}
    });

    testScoped(
      'a successful hook keeps task edits and drops the ref',
      () async {
        write('a.dart', 'staged\n');
        run('git', ['add', 'a.dart']);

        final sha = (await git.createBackup())!;
        // The formatter rewrote the file and the hook went on to succeed.
        write('a.dart', 'formatted\n');

        await executorFor(hookWith()).releaseBackup(sha, succeeded: true);

        expect(
          read('a.dart'),
          'formatted\n',
          reason: 'a successful hook must not roll back its own tasks',
        );
        expect(backupRefExists(), isFalse);
      },
      git: () => git,
    );

    testScoped('a failed hook rolls back and drops the ref', () async {
      write('a.dart', 'staged\n');
      run('git', ['add', 'a.dart']);
      write('a.dart', 'staged\nunstaged\n');

      final sha = (await git.createBackup())!;
      write('a.dart', 'CLOBBERED\n');

      await executorFor(hookWith()).releaseBackup(sha, succeeded: false);

      expect(read('a.dart'), 'staged\nunstaged\n');
      expect(run('git', ['show', ':a.dart']), 'staged');
      expect(backupRefExists(), isFalse);
    }, git: () => git);

    testScoped('keeps the ref when the rollback fails', () async {
      // A sha that is not a stash commit has no index parent, so the restore
      // cannot complete -- exactly when the snapshot must be preserved.
      final head = run('git', ['rev-parse', 'HEAD']);
      run('git', ['update-ref', GitService.backupRef, head]);

      await executorFor(hookWith()).releaseBackup(head, succeeded: false);

      expect(
        backupRefExists(),
        isTrue,
        reason: 'the snapshot is the last copy of the work, never drop it',
      );
    }, git: () => git);

    testScoped('does nothing when no backup was taken', () async {
      write('a.dart', 'untouched\n');

      await expectLater(
        executorFor(hookWith()).releaseBackup(null, succeeded: false),
        completes,
      );

      expect(read('a.dart'), 'untouched\n');
    }, git: () => git);

    group('opt out', () {
      test('backup defaults to true', () {
        expect(hookWith().backup, isTrue);
        expect(
          PreCommitHook(
            tasks: [ShellTask.always(name: 'x', commands: (_) => [])],
          ).backup,
          isTrue,
        );
      });

      test('backup can be disabled per hook', () {
        expect(hookWith(backup: false).backup, isFalse);
      });

      test('backup participates in equality', () {
        expect(hookWith(), isNot(hookWith(backup: false)));
      });
    });
  });
}
