import 'dart:io' as io;

import 'package:git_hooks/entrypoint/hook_execution/label_maker.dart';
import 'package:git_hooks/entrypoint/hook_execution/pending_tasks.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/services/git/git_service.dart';
import 'package:git_hooks/utils/multi_line_progress.dart';
import 'package:mason_logger/mason_logger.dart';

class HookExecutor {
  const HookExecutor(
    this.hook, {
    required this.stdout,
    required this.hookName,
    required this.logger,
    required this.gitService,
    required this.resolver,
    required this.debug,
  });

  final Hook hook;
  final io.Stdout stdout;
  final String hookName;
  final Logger logger;
  final GitService gitService;
  final Resolver resolver;
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
      logger.info('No files to process');
      return (<String>[], 0);
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
        long: const Duration(milliseconds: 5000),
      );

  Future<void> _wait(Duration duration) async {
    logger.detail('Waiting for $duration');
    await Future<void>.delayed(duration);
  }

  Future<int> run() async {
    logger.info('Preparing files');
    final context = await gitService.prepareFiles(backup: hook.backupFiles);

    if (context.hidePartiallyStaged) {
      logger.info('Hiding partially staged files');
      await gitService.checkoutFiles(context.partiallyStagedFiles);
    }

    if (debug) await _wait(durations.short);

    logger.info('Running $hookName hook');

    final allFilesResult = await this.allFiles;
    if (allFilesResult case (_, final int code)) {
      return code;
    }
    final (allFiles, _) = allFilesResult;
    logger.detail('Found ${allFiles.length} files');

    if (debug) await _wait(durations.short);

    logger.detail('Resolving files');
    final resolvedHook = resolver.resolve(allFiles);

    final pendingTasks = PendingTasks(
      resolvedHook,
      logger: logger,
    );

    if (pendingTasks.tasks.every((e) => e.files.isEmpty)) {
      logger.info('No matching files');
      return 0;
    }

    final labelMaker = LabelMaker(
      stdout: stdout,
      tasks: pendingTasks.tasks,
      nameOfHook: hookName,
    );

    logger.detail('Starting tasks');
    if (debug) await _wait(durations.short);

    final progress = MultiLineProgress(createLabel: labelMaker.create)..start();

    pendingTasks.start();

    await pendingTasks.wait();

    if (pendingTasks.wasKilled) {
      progress
        ..dispose()
        ..print();

      logger.detail('Hook was killed');
      return 1;
    }

    await progress.closeNextFrame();

    logger
      ..detail('Tasks finished')
      ..flush()
      ..write('\n');

    for (final task in pendingTasks.tasks) {
      if (task.code case final int code when code != 0) {
        logger.detail('Task failed: ${task.command.name}');
        return code;
      }
    }

    if (hook.backupFiles) {
      logger.info('Applying modifications');
      if (debug) await _wait(durations.short);
      await gitService.applyModifications();
      if (debug) await _wait(durations.long);
    }

    Future<void> finish() async {
      logger.detail('making sure all deleted files stay deleted');
      if (debug) await _wait(durations.short);
      await gitService.ensureDeletedFiles(context.deletedFiles);

      if (debug) await _wait(durations.long);

      logger.detail('deleting patch');
      await gitService.deletePatch();

      if (debug) await _wait(durations.short);

      logger.detail('deleting stash');
      await gitService.dropBackupStash();
    }

    logger.info('Restoring unstaged changes');
    if (!await gitService.restoreUnstagedChanges()) {
      logger.err('Failed to restore unstaged changes due to merge conflicts');
      if (debug) await _wait(durations.long);

      final stash = context.stashHash;
      if (stash == null) {
        return 1;
      }

      logger.detail('Forcing hard reset to HEAD');
      await gitService.restoreStash();

      if (debug) await _wait(durations.long);

      await finish();

      return 1;
    }

    await finish();

    if (hook.allowEmpty) {
      return 0;
    }

    final files = await gitService.diffFiles(
      diffArgs: hook.diffArgs,
      diffFilters: hook.diffFilters,
    );

    if (files != null && files.isEmpty) {
      logger.info('No changes to commit');
      return 1;
    }

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
