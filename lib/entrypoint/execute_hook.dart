import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:git_hooks/entrypoint/hook_execution/label_maker.dart';
import 'package:git_hooks/entrypoint/hook_execution/pending_tasks.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:git_hooks/utils/multi_line_progress.dart';
import 'package:mason_logger/mason_logger.dart';

// TODO(mrgnhnt): Handle when user presses CTRL+C
/*
var attemptsToKill = 0;
final stream = Platform.isWindows
    ? ProcessSignal.sigint.watch()
    : StreamGroup.merge(
        [
          ProcessSignal.sigterm.watch(),
          ProcessSignal.sigint.watch(),
        ],
      );

_killSubscription ??= stream.listen((event) {
  logger.detail('Received SIGINT');
  if (attemptsToKill > 0) {
    exit(1);
  } else if (attemptsToKill == 0) {
    stop().ignore();
  }

  attemptsToKill++;
});
*/

Future<void> executeHook(String name, Hook hook) async {
  const fs = LocalFileSystem();

  final logger = Logger()..level = Level.verbose;
  final gitService = GitService(
    logger: logger,
    fs: fs,
  );

  final resolver = Resolver(
    hook: hook,
    fs: fs,
  );

  try {
    logger.info('starting...');
    exitCode = await run(
      hook,
      hookName: name,
      logger: logger,
      gitService: gitService,
      resolver: resolver,
    );
  } catch (e) {
    exitCode = 1;
  }

  exit(exitCode);
}

Future<int> run(
  Hook hook, {
  required String hookName,
  required Logger logger,
  required GitService gitService,
  required Resolver resolver,
}) async {
  logger.info('running $hookName hook');

  final allFiles = await gitService.getChangedFiles(hook.diff);

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
