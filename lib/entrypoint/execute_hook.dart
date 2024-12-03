import 'dart:io';

import 'package:file/local.dart';
import 'package:git_hooks/git_hooks.dart';
import 'package:mason_logger/mason_logger.dart';

Future<void> executeHook(Hook hook) async {
  const fs = LocalFileSystem();

  final logger = Logger();
  final gitService = GitService(
    logger: logger,
    fs: fs,
  );

  final resolver = Resolver(
    hook: hook,
    fs: fs,
  );

  final files = await gitService.getChangedFiles();

  if (files == null) {
    logger.err('Could not get changed files');
    exit(1);
  }

  if (files.isEmpty) {
    logger.info('No files to process');
    exit(0);
  }

  final resolvedHooks = resolver.resolve(files).toList();

  for (final hook in resolvedHooks) {
    for (final command in hook.commands) {
      final progress = logger.progress(command);

      final result = await Process.run(
        'bash',
        [
          '-c',
          command,
        ],
      );

      if (result.exitCode != 0) {
        progress.fail();
        logger
          ..info(result.stdout as String)
          ..err(result.stderr as String);
        exit(1);
      }

      progress.complete();
    }
  }

  logger.write('\n');
  exit(0);
}
