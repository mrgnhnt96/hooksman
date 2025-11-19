import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/entrypoint/hook_execution/label_maker.dart';
import 'package:hooksman/entrypoint/hook_execution/pending_hook.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/utils/multi_line_progress.dart';
import 'package:mason_logger/mason_logger.dart';

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

    if (!pendingHook.topLevelTasks.any((e) => e.shouldAlwaysRun)) {
      if (pendingHook.topLevelTasks.every((e) => e.files.isEmpty)) {
        logger.info(
          darkGray.wrap('Skipping $hookName hook, no files match any tasks'),
        );
        return 0;
      }
    }

    final context = await git.prepareFiles();

    final labelMaker = LabelMaker(
      pendingHook: pendingHook,
      nameOfHook: hookName,
      debug: debug,
    );

    logger.detail('Starting tasks');
    await _wait(durations.short);

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
        return 1;
      }
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

    if (hook case PreCommitHook(allowEmpty: true)) {
      logger.detail('--FINISHED--');
      return 0;
    }

    final files = await git.diffFiles(
      diffArgs: hook.diffArgs,
      diffFilters: hook.diffFilters,
    );

    if (files.isEmpty) {
      logger
        ..info('No changes to commit')
        ..detail('--FINISHED--');
      return 1;
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
