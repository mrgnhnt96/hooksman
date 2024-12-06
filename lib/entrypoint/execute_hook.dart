import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:git_hooks/entrypoint/hook_execution/hook_executor.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

Future<void> executeHook(String name, Hook hook) async {
  const fs = LocalFileSystem();

  final level = switch (Platform.environment['LOG_LEVEL']) {
    'loud' || 'all' || 'verbose' => Level.verbose,
    'info' => Level.info,
    'warning' => Level.warning,
    'error' => Level.error,
    'critical' => Level.critical,
    _ => Level.info,
  };

  final logger = Logger()..level = level;
  final gitService = GitService(
    logger: logger,
    fs: fs,
  );

  final resolver = Resolver(
    hook: hook,
    fs: fs,
  );

  try {
    final executor = HookExecutor(
      hook,
      stdout: stdout,
      hookName: name,
      logger: logger,
      gitService: gitService,
      resolver: resolver,
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
