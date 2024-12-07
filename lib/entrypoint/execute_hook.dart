import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:hooksman/entrypoint/hook_execution/hook_executor.dart';
import 'package:hooksman/models/debug_hook.dart';
import 'package:hooksman/models/hook.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

Future<void> executeHook(String name, Hook hook) async {
  const fs = LocalFileSystem();

  final debug = hook is DebugHook;

  final level = switch (debug) {
    true => Level.verbose,
    false => Level.info,
  };

  final logger = Logger()..level = level;
  final gitService = GitService(
    logger: logger,
    fs: fs,
  );

  try {
    final executor = HookExecutor(
      hook,
      stdout: stdout,
      hookName: name,
      logger: logger,
      gitService: gitService,
      debug: debug,
    );

    final canRun = await executor.runChecks();

    if (!canRun) {
      exitCode = 1;
    } else {
      exitCode = await executor.run();
    }
  } catch (e) {
    exitCode = 1;
  }

  exit(exitCode);
}
