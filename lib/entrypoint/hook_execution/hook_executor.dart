import 'package:async/async.dart';
import 'package:hooksman/app/data/steps.dart';
import 'package:hooksman/app/hooksman_app.dart';
import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/services/git/git_context.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart';

/// Exit code after successful tasks given the post-task file list.
///
/// Only [PreCommitHook] without [PreCommitHook.allowEmpty] fails when empty.
int postSuccessExitCode(Hook hook, List<String> files) {
  if (hook case PreCommitHook(allowEmpty: false)) {
    if (files.isEmpty) return 1;
  }
  return 0;
}

class HookExecutor {
  const HookExecutor(this.hook, {required this.hookName});

  final Hook hook;
  final String hookName;

  bool get debug => args['loud'] == true;

  Future<(List<String>, int?)> get allFiles async {
    final allFiles = await git.diffFiles(
      diffArgs: hook.diffArgs,
      diffFilters: hook.diffFilters,
    );

    if (allFiles.isEmpty) {
      if (!hook.shouldRunOnEmpty) {
        logger.info(
          darkGray.wrap('Skipping $hookName hook, no files to process'),
        );
        return (<String>[], 0);
      }
    }

    return (allFiles, null);
  }

  ({Duration short, Duration medium, Duration long}) get durations => (
    short: const Duration(milliseconds: 1000),
    medium: const Duration(milliseconds: 2000),
    long: const Duration(milliseconds: 3000),
  );

  Future<void> _wait(Duration duration) async {
    if (!debug) return;

    logger.detail('Waiting for $duration');
    await Future<void>.delayed(duration);
  }

  Future<int> run() async {
    final allFilesResult = await this.allFiles;
    if (allFilesResult case (_, final int code)) {
      return code;
    }
    final (allFiles, _) = allFilesResult;
    logger.detail('Found ${allFiles.length} files');
    for (final file in allFiles) {
      logger.detail('  - $file');
    }

    await _wait(durations.short);

    logger.detail('Resolving files');

    final pendingHook = PendingHook(hook.resolve(allFiles), logger: logger);

    if (!hook.shouldRunOnEmpty &&
        !pendingHook.topLevelTasks.any((e) => e.shouldAlwaysRun)) {
      if (pendingHook.topLevelTasks.every((e) => e.files.isEmpty)) {
        logger.info(
          darkGray.wrap('Skipping $hookName hook, no files match any tasks'),
        );
        return 0;
      }
    }

    final context = await git.prepareFiles();

    // Snapshot before the first task touches a file, so any exit other than a
    // clean success can put the repository back exactly as it was found.
    final backup = hook.backup ? await git.createBackup() : null;

    var succeeded = false;
    try {
      final code = await _runTasks(pendingHook, context);
      succeeded = code == 0;
      return code;
    } finally {
      await releaseBackup(backup, succeeded: succeeded);
    }
  }

  /// Rolls the repository back to [backup] unless the hook succeeded, then
  /// releases the snapshot.
  ///
  /// The ref is deliberately left in place when a restore fails -- that is the
  /// one case where the user's only remaining copy of their work is the
  /// snapshot itself.
  @visibleForTesting
  Future<void> releaseBackup(String? backup, {required bool succeeded}) async {
    if (backup == null) return;

    if (succeeded) {
      await git.dropBackup();
      return;
    }

    logger.detail('Hook did not succeed, restoring $backup');

    if (await git.restoreBackup(backup)) {
      logger.detail('Restored the index and working tree');
      await git.dropBackup();
      return;
    }

    logger.err(
      'Failed to restore your files after the hook did not succeed.\n'
      'Your work is safe in a backup. Recover it by running:\n'
      '  git stash apply ${GitService.backupRef}',
    );
  }

  Future<int> _runTasks(PendingHook pendingHook, GitContext context) async {
    logger.detail('Starting tasks');
    await _wait(durations.short);

    final steps = Steps();

    final runner = CancelableOperation.fromFuture(
      runApp(
        HooksmanApp(
          pendingHook: pendingHook,
          nameOfHook: hookName,
          debug: debug,
          steps: steps,
        ),
        enableHotReload: false,
      ),
      onCancel: () {
        // Stop the nocterm event loop so runApp completes. Do not use
        // shutdownApp()/requestExit — that would exit(0) and race the hook's
        // intentional non-zero exit after Ctrl+C.
        try {
          TerminalBinding.instance.shutdown();
        } catch (_) {}
      },
    );

    steps.current = Step.running;
    await pendingHook.start();
    await pendingHook.wait();

    final failed = pendingHook.topLevelTasks.any((task) {
      final code = task.code;
      return code != null && code != 0;
    });

    if (pendingHook.wasKilled) {
      steps.current = Step.quit;
      logger.detail('Hook was killed');
    } else if (failed) {
      steps.current = Step.error;
      for (final task in pendingHook.topLevelTasks) {
        final code = task.code;
        if (code != null && code != 0) {
          logger.detail(
            'Task failed: ${task.resolvedTask.original.resolvedName}',
          );
        }
      }
    } else {
      steps.current = Step.complete;
      logger.detail('Tasks finished');
    }

    // Let the final step paint before tearing down the TUI.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await runner.cancel();

    if (logger.level.index == Level.verbose.index || !pendingHook.wasKilled) {
      logger.flush();
    }
    if (!pendingHook.wasKilled) {
      logger.write('\n');
    }

    if (pendingHook.wasKilled || failed) {
      logger.detail('stopping hook tasks');
      return 1;
    }

    if (hook is PreCommitHook) {
      logger.detail('Applying modifications');
      for (final file in context.nonStagedFiles) {
        logger.detail('  - $file');
      }
      await _wait(durations.short);
      await git.applyModifications([
        ...context.nonStagedFiles,
        ...context.deletedFiles,
      ]);
      await _wait(durations.long);
    } else {
      logger.detail('Skipped applying modifications for $hookName');
    }

    // Only PreCommitHook (without allowEmpty) should fail when tasks left
    // nothing to commit. Other hooks succeed after successful task runs.
    if (hook case PreCommitHook(allowEmpty: false)) {
      final files = await git.diffFiles(
        diffArgs: hook.diffArgs,
        diffFilters: hook.diffFilters,
      );

      final code = postSuccessExitCode(hook, files);
      if (code != 0) {
        logger
          ..info('No changes to commit')
          ..detail('--FINISHED--');
        return code;
      }
    }

    logger.detail('--FINISHED--');
    return 0;
  }

  Future<bool> runChecks() async {
    if (!await git.isGitInstalled()) {
      return false;
    }

    if (!await git.isGitRepository()) {
      return false;
    }

    return true;
  }
}
