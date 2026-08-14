@Timeout(Duration(minutes: 3))
library;

import 'dart:io';

import 'package:hooksman/services/git/git_service.dart';
import 'package:test/test.dart';

import '../../utils/test_scoped.dart';

/// These tests drive a real `git` binary against real repositories on disk.
///
/// The backup/restore path is the one place hooksman can destroy work that
/// exists nowhere else, so it is verified against git's actual behaviour
/// rather than against a mocked process.
void main() {
  group('backup and restore', () {
    late Directory repo;
    late GitService git;

    /// Runs [args] in the test repository, failing loudly on a non-zero exit.
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

    /// Files staged relative to `HEAD`, as `status\tpath` entries.
    List<String> stagedStatus() => run('git', [
      'diff',
      '--cached',
      '--name-status',
      'HEAD',
    ]).split('\n').where((e) => e.isNotEmpty).toList();

    /// Files with unstaged working-tree changes.
    List<String> unstagedStatus() => run('git', [
      'diff',
      '--name-status',
    ]).split('\n').where((e) => e.isNotEmpty).toList();

    /// The content git would commit for [path] right now.
    String stagedContent(String path) => run('git', ['show', ':$path']);

    bool backupRefExists() => run('git', [
      'rev-parse',
      '--verify',
      '--quiet',
      GitService.backupRef,
    ], allowFail: true).isNotEmpty;

    setUp(() {
      repo = Directory.systemTemp.createTempSync('hooksman_backup_');
      // Pin git to the temp repo rather than mutating the process working
      // directory, which concurrently running suites share.
      git = GitService(workingDirectory: repo.path);

      run('git', ['init', '--quiet', '--initial-branch=main', '.']);
      run('git', ['config', 'user.email', 'test@example.com']);
      run('git', ['config', 'user.name', 'Test']);
      run('git', ['config', 'commit.gpgsign', 'false']);
    });

    tearDown(() {
      try {
        repo.deleteSync(recursive: true);
      } catch (_) {}
    });

    /// Establishes a first commit so `HEAD` exists.
    void seed() {
      write('a.dart', 'orig-a\n');
      write('b.dart', 'orig-b\n');
      write('c.dart', 'orig-c\n');
      run('git', ['add', '-A']);
      run('git', ['commit', '--quiet', '-m', 'init']);
    }

    group('#createBackup', () {
      testScoped('returns null when there is nothing to back up', () async {
        seed();

        expect(await git.createBackup(), isNull);
        expect(backupRefExists(), isFalse);
      });

      testScoped('returns null on an unborn HEAD', () async {
        // The very first commit in a repository: `git stash create` cannot
        // snapshot anything, and the hook must still be allowed to run.
        write('a.dart', 'first\n');
        run('git', ['add', '-A']);

        expect(await git.createBackup(), isNull);
        expect(backupRefExists(), isFalse);
      });

      testScoped('anchors the snapshot at the backup ref', () async {
        seed();
        write('a.dart', 'changed\n');

        final sha = await git.createBackup();

        expect(sha, isNotNull);
        expect(backupRefExists(), isTrue);
        expect(run('git', ['rev-parse', GitService.backupRef]), sha);
      });

      testScoped('leaves the index and working tree untouched', () async {
        seed();
        write('a.dart', 'staged-a\n');
        run('git', ['add', 'a.dart']);
        write('b.dart', 'unstaged-b\n');

        final stagedBefore = stagedStatus();
        final unstagedBefore = unstagedStatus();

        await git.createBackup();

        expect(stagedStatus(), stagedBefore);
        expect(unstagedStatus(), unstagedBefore);
        expect(read('a.dart'), 'staged-a\n');
        expect(read('b.dart'), 'unstaged-b\n');
      });

      testScoped('does not push onto the stash stack', () async {
        seed();
        write('a.dart', 'changed\n');

        await git.createBackup();

        expect(run('git', ['stash', 'list']), isEmpty);
      });
    });

    group('#restoreBackup', () {
      testScoped('undoes a rewrite of a fully staged file', () async {
        seed();
        write('a.dart', 'void main(){}\n');
        run('git', ['add', 'a.dart']);

        final sha = (await git.createBackup())!;
        // A formatter rewrites the file, then a later task fails.
        write('a.dart', 'void main() {}\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('a.dart'), 'void main(){}\n');
        expect(stagedContent('a.dart'), 'void main(){}');
      });

      testScoped('recovers unstaged work in a partially staged file', () async {
        // The classic loss case: a file is half staged, and a task overwrites
        // the whole file, taking the uncommitted half with it.
        seed();
        write('a.dart', 'staged-half\n');
        run('git', ['add', 'a.dart']);
        write('a.dart', 'staged-half\nWORK-IN-PROGRESS\n');

        final sha = (await git.createBackup())!;
        write('a.dart', 'CLOBBERED\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('a.dart'), 'staged-half\nWORK-IN-PROGRESS\n');
        expect(stagedContent('a.dart'), 'staged-half');
      });

      testScoped('recovers a file a task deleted', () async {
        seed();
        write('a.dart', 'changed\n');
        run('git', ['add', 'a.dart']);

        final sha = (await git.createBackup())!;
        File('${repo.path}/c.dart').deleteSync();

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('c.dart'), 'orig-c\n');
      });

      testScoped('unstages a file a task added to the index', () async {
        seed();
        write('a.dart', 'changed\n');
        run('git', ['add', 'a.dart']);

        final sha = (await git.createBackup())!;
        // Codegen writes a new file and stages it, then the hook fails.
        write('generated.g.dart', 'generated\n');
        run('git', ['add', 'generated.g.dart']);

        expect(await git.restoreBackup(sha), isTrue);
        expect(stagedStatus(), ['M\ta.dart']);
        expect(read('generated.g.dart'), isNull);
      });

      testScoped('leaves untracked files alone', () async {
        // `stash create` does not capture untracked files, so restoring them
        // is impossible -- deleting them would be pure data loss.
        seed();
        write('a.dart', 'changed\n');
        run('git', ['add', 'a.dart']);
        write('notes.md', 'my notes\n');

        final sha = (await git.createBackup())!;
        write('scratch.txt', 'task output\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('notes.md'), 'my notes\n');
        expect(read('scratch.txt'), 'task output\n');
      });

      testScoped('restores when only unstaged changes exist', () async {
        seed();
        write('a.dart', 'unstaged-only\n');

        final sha = (await git.createBackup())!;
        write('a.dart', 'CLOBBERED\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('a.dart'), 'unstaged-only\n');
        expect(stagedStatus(), isEmpty);
      });

      testScoped('restores a staged deletion', () async {
        seed();
        run('git', ['rm', '--quiet', 'c.dart']);

        final sha = (await git.createBackup())!;
        // A task resurrects the file the user meant to delete.
        write('c.dart', 'resurrected\n');
        run('git', ['add', 'c.dart']);

        expect(await git.restoreBackup(sha), isTrue);
        expect(stagedStatus(), ['D\tc.dart']);
        expect(read('c.dart'), isNull);
      });

      testScoped('restores a staged rename', () async {
        seed();
        run('git', ['mv', 'c.dart', 'renamed.dart']);

        final sha = (await git.createBackup())!;
        write('renamed.dart', 'CLOBBERED\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('renamed.dart'), 'orig-c\n');
        expect(read('c.dart'), isNull);
      });

      testScoped('restores binary content byte for byte', () async {
        seed();
        final bytes = List<int>.generate(512, (i) => i % 256);
        File('${repo.path}/blob.bin').writeAsBytesSync(bytes);
        run('git', ['add', 'blob.bin']);

        final sha = (await git.createBackup())!;
        File('${repo.path}/blob.bin').writeAsBytesSync([0, 0, 0]);

        expect(await git.restoreBackup(sha), isTrue);
        expect(File('${repo.path}/blob.bin').readAsBytesSync(), bytes);
      });

      testScoped('restores files in nested directories', () async {
        seed();
        write('lib/deep/nested.dart', 'nested\n');
        run('git', ['add', '-A']);
        run('git', ['commit', '--quiet', '-m', 'nested']);
        write('lib/deep/nested.dart', 'staged\n');
        run('git', ['add', '-A']);

        final sha = (await git.createBackup())!;
        write('lib/deep/nested.dart', 'CLOBBERED\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('lib/deep/nested.dart'), 'staged\n');
      });

      testScoped('preserves an in-progress merge', () async {
        seed();
        run('git', ['checkout', '--quiet', '-b', 'other']);
        write('a.dart', 'other\n');
        run('git', ['commit', '--quiet', '-am', 'other']);
        run('git', ['checkout', '--quiet', 'main']);
        write('a.dart', 'mine\n');
        run('git', ['commit', '--quiet', '-am', 'mine']);
        run('git', ['merge', 'other'], allowFail: true);
        write('a.dart', 'resolved\n');
        run('git', ['add', 'a.dart']);

        final sha = (await git.createBackup())!;
        write('a.dart', 'CLOBBERED\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(read('a.dart'), 'resolved\n');
        expect(
          File('${repo.path}/.git/MERGE_HEAD').existsSync(),
          isTrue,
          reason: 'restoring must not abandon the merge in progress',
        );
      });

      testScoped('returns false for a sha that is not a stash', () async {
        seed();
        // A plain commit has no second parent, so the index restore must fail
        // rather than silently leaving a half-restored repository.
        final head = run('git', ['rev-parse', 'HEAD']);

        expect(await git.restoreBackup(head), isFalse);
      });

      testScoped('is idempotent', () async {
        seed();
        write('a.dart', 'staged\n');
        run('git', ['add', 'a.dart']);
        write('a.dart', 'staged\nunstaged\n');

        final sha = (await git.createBackup())!;
        write('a.dart', 'CLOBBERED\n');

        expect(await git.restoreBackup(sha), isTrue);
        expect(await git.restoreBackup(sha), isTrue);
        expect(read('a.dart'), 'staged\nunstaged\n');
        expect(stagedContent('a.dart'), 'staged');
      });
    });

    group('#dropBackup', () {
      testScoped('deletes the ref', () async {
        seed();
        write('a.dart', 'changed\n');
        await git.createBackup();
        expect(backupRefExists(), isTrue);

        await git.dropBackup();

        expect(backupRefExists(), isFalse);
      });

      testScoped('is safe when no backup exists', () async {
        seed();

        await expectLater(git.dropBackup(), completes);
      });
    });

    group('the reported scenario', () {
      testScoped('a failed commit leaves staging exactly as it was', () async {
        // Docs staged earlier in the session, then a code change staged and
        // committed. The formatter rewrites the code, a later task fails.
        seed();
        write('docs.md', '# docs\nmore docs\n');
        run('git', ['add', 'docs.md']);
        write('a.dart', 'void main(){print(1);}\n');
        run('git', ['add', 'a.dart']);

        final stagedBefore = stagedStatus();
        final sha = (await git.createBackup())!;

        write('a.dart', 'void main() {\n  print(1);\n}\n');

        expect(await git.restoreBackup(sha), isTrue);

        expect(stagedStatus(), stagedBefore);
        expect(read('a.dart'), 'void main(){print(1);}\n');
        expect(stagedContent('docs.md'), '# docs\nmore docs');

        // The retry now commits exactly what was staged, unformatted.
        run('git', ['commit', '--quiet', '-m', 'retry']);
        expect(
          run('git', ['show', '--name-only', '--format=', 'HEAD']).split('\n'),
          containsAll(<String>['a.dart', 'docs.md']),
        );
      });
    });
  });
}
