import 'dart:async';
import 'dart:io';

import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/compiler.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';
import 'package:hooksman/deps/stdout.dart';
import 'package:hooksman/entrypoint/hook_execution/hook_executor.dart';
import 'package:hooksman/hooks/hook.dart';
import 'package:hooksman/models/args.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:scoped_deps/scoped_deps.dart';

Future<void> executeHook(String name, Hook hook, List<String> args) async {
  String? remoteName;
  String? remoteUrl;
  if (args case [final String remote, final String url]) {
    remoteName = remote;
    remoteUrl = url;
  }

  final logger = Logger();
  if (hook.verbose) {
    logger.level = Level.verbose;
  } else {
    logger.level = Level.error;
  }

  return runScoped(
    () => _run(name, hook),
    values: {
      argsProvider.overrideWith(
        () => Args(args: {'loud': hook.verbose, 'quiet': !hook.verbose}),
      ),
      loggerProvider.overrideWith(() => logger),
      gitProvider.overrideWith(
        () => GitService(remoteName: remoteName, remoteUrl: remoteUrl),
      ),
      fsProvider,
      processProvider,
      compilerProvider,
      stdoutProvider,
    },
  );
}

Future<int> _run(String name, Hook hook) async {
  try {
    final executor = HookExecutor(hook, hookName: name);

    final canRun = await executor.runChecks();

    if (!canRun) {
      exitCode = 1;
    } else {
      exitCode = await executor.run();
    }
  } catch (e, stack) {
    logger
      ..err('Error running hook')
      ..detail('Error: $e')
      ..detail('Stack:\n$stack');
    exitCode = 1;
  }

  exit(exitCode);
}
