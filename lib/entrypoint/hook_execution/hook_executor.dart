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
  });

  final Hook hook;
  final io.Stdout stdout;
  final String hookName;
  final Logger logger;
  final GitService gitService;
  final Resolver resolver;

  Future<int> run() async {
    logger.info('Running $hookName hook');

    final allFiles = await gitService.diffFiles(
      diffArgs: hook.diffArgs,
      diffFilters: hook.diffFilters,
    );

    if (allFiles == null) {
      logger.err('Could not get changed files');
      return 1;
    }

    if (allFiles.isEmpty) {
      logger.info('No files to process');
      return 0;
    }

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

    final progress = MultiLineProgress(createLabel: labelMaker.create)..start();

    pendingTasks.start();

    await pendingTasks.wait();

    if (pendingTasks.wasKilled) {
      progress
        ..dispose()
        ..print();
      return 1;
    }

    await progress.closeNextFrame();

    logger
      ..flush()
      ..write('\n');

    for (final task in pendingTasks.tasks) {
      if (task.code case final int code when code != 0) {
        return code;
      }
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

    if (!await gitService.hasAtLeastOneCommit()) {
      return false;
    }

    return true;
  }
}
