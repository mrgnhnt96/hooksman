import 'dart:io' as io;

import 'package:hooksman/entrypoint/hook_execution/label_maker.dart';
import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:hooksman/utils/multi_line_progress.dart';
import 'package:mason_logger/mason_logger.dart';

class HookExecutor {
  const HookExecutor(
    this.hook, {
    required this.stdout,
    required this.hookName,
    required this.logger,
    required this.gitService,
    required this.debug,
  });

  final Hook hook;
  final io.Stdout stdout;
  final String hookName;
  final Logger logger;
  final GitService gitService;
  final bool debug;

  Future<(List<String>, int?)> get allFiles async {
    final allFiles = await gitService.diffFiles(
      diffArgs: hook.diffArgs,
      diffFilters: hook.diffFilters,
    );

    if (allFiles == null) {
      logger.err('Could not get changed files');
      return (<String>[], 1);
    }

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

  ({
    Duration short,
    Duration medium,
    Duration long,
  }) get durations => (
        short: const Duration(milliseconds: 1000),
        medium: const Duration(milliseconds: 2000),
        long: const Duration(milliseconds: 3000),
      );

  Future<void> _wait(Duration duration) async {
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

    if (debug) await _wait(durations.short);

    logger.detail('Resolving files');

    final pendingHook = PendingHook(
      hook.resolve(allFiles),
      logger: logger,
    );

    if (!pendingHook.topLevelTasks.any((e) => e.shouldAlwaysRun)) {
      if (pendingHook.topLevelTasks.every((e) => e.files.isEmpty)) {
        logger.info(
          darkGray.wrap('Skipping $hookName hook, no files match any tasks'),
        );
        return 0;
      }
    }

    logger
      ..info(darkGray.wrap('Running $hookName hook'))
      ..detail('Preparing files');
    final context = await gitService.prepareFiles(backup: hook.backupFiles);
    if (debug) await _wait(durations.short);

    if (context.hidePartiallyStaged) {
      logger.detail(
        'Hiding partially staged files '
        '(${context.partiallyStagedFiles.length})',
      );
      await gitService.checkoutFiles(context.partiallyStagedFiles);
    }

    final labelMaker = LabelMaker(
      stdout: stdout,
      pendingHook: pendingHook,
      nameOfHook: hookName,
      debug: debug,
    );

    logger.detail('Starting tasks');
    if (debug) await _wait(durations.short);

    final progress = MultiLineProgress(createLabel: labelMaker.create)..start();

    pendingHook.start();

    await pendingHook.wait();

    if (pendingHook.wasKilled) {
      progress
        ..dispose()
        ..print();

      logger.detail('Hook was killed');
      if (logger.level.index == Level.verbose.index) {
        logger.flush();
      }
    } else {
      await progress.closeNextFrame();

      logger
        ..detail('Tasks finished')
        ..flush()
        ..write('\n');
    }

    Future<void> finish({
      required bool cleanUp,
    }) async {
      if (cleanUp) {
        logger.detail('deleting patch');
        await gitService.deletePatch();
      }

      logger.detail('restoring merge statuses');
      gitService.restoreMergeStatuses(
        msg: context.mergeMsg,
        mode: context.mergeMode,
        head: context.mergeHead,
      );

      if (debug) await _wait(durations.short);

      logger.detail('dropping stash');
      await gitService.dropBackupStash();
    }

    Future<int> fail() async {
      final stash = context.stashHash;
      if (stash == null) {
        return 1;
      }

      if (debug) await _wait(durations.short);

      logger.detail('Restoring stash');
      final restoredStash = await gitService.restoreStash();

      if (debug) await _wait(durations.long);

      logger.detail('making sure all deleted files stay deleted '
          '(${context.deletedFiles.length})');

      if (debug) await _wait(durations.short);
      await gitService.ensureDeletedFiles(context.deletedFiles);

      await finish(
        cleanUp: restoredStash,
      );

      return 1;
    }

    var failed = false;
    for (final task in pendingHook.topLevelTasks) {
      if (task.code case final int code when code != 0) {
        failed = true;
        logger.detail(
          'Task failed: ${task.resolvedTask.original.resolvedName}',
        );
      }

      if (failed) {
        logger
          ..detail('stopping hook tasks')
          ..flush();
        return await fail();
      }
    }

    if (hook.backupFiles) {
      logger.detail('Applying modifications');
      for (final file in context.nonStagedFiles) {
        logger.detail('  - $file');
      }
      if (debug) await _wait(durations.short);
      await gitService.applyModifications(context.nonStagedFiles);
      if (debug) await _wait(durations.long);
    } else {
      logger.detail('Skipping modifications due to diffArgs being set');
    }

    if (context.hidePartiallyStaged) {
      logger.detail('Restoring unstaged changes');
      if (!await gitService.applyPatch()) {
        logger.err('Failed to restore unstaged changes due to merge conflicts');
        if (debug) await _wait(durations.long);

        await fail();
      }
    }

    await finish(
      cleanUp: true,
    );

    if (hook.allowEmpty) {
      logger.detail('--FINISHED--');
      return 0;
    }

    final files = await gitService.diffFiles(
      diffArgs: hook.diffArgs,
      diffFilters: hook.diffFilters,
    );

    if (files != null && files.isEmpty) {
      logger
        ..info('No changes to commit')
        ..detail('--FINISHED--');
      return 1;
    }

    logger.detail('--FINISHED--');
    return 0;
  }

  Future<bool> runChecks() async {
    if (!await gitService.isGitInstalled()) {
      return false;
    }

    if (!await gitService.isGitRepository()) {
      return false;
    }

    return true;
  }
}
