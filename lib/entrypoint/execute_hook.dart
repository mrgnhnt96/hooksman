import 'dart:io';

import 'package:file/local.dart';
import 'package:git_hooks/git_hooks.dart';
import 'package:git_hooks/models/dart_script.dart';
import 'package:git_hooks/models/shell_script.dart';
import 'package:mason_logger/mason_logger.dart';

Future<void> executeHook(Hook hook) async {
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
    exitCode = await _run(
      hook,
      logger: logger,
      gitService: gitService,
      resolver: resolver,
    );
  } catch (e) {
    exitCode = 1;
  }
}

Future<int> _run(
  Hook hook, {
  required Logger logger,
  required GitService gitService,
  required Resolver resolver,
}) async {
  final files = await gitService.getChangedFiles();

  if (files == null) {
    logger.err('Could not get changed files');
    return 1;
  }

  if (files.isEmpty) {
    logger.info('No files to process');
    return 0;
  }

  final resolvedHook = resolver.resolve(files);

  for (final command in resolvedHook.commands) {
    final result = await switch (command) {
      ShellScript() => _runShellScript(command, files, logger),
      DartScript() => _runDartScript(command, files, logger),
      _ => throw ArgumentError(
          'Unsupported command type',
          command.runtimeType.toString(),
        ),
    };

    if (result != 0) {
      return result;
    }
  }

  logger.write('\n');
  return 0;
}

Future<int> _runDartScript(
  DartScript script,
  List<String> files,
  Logger logger,
) async {
  try {
    return await script.script(files);
  } catch (e) {
    logger.err(e.toString());
    return 1;
  }
}

Future<int> _runShellScript(
  ShellScript script,
  List<String> files,
  Logger logger,
) async {
  for (final command in script.commands(files)) {
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
      return 1;
    }

    progress.complete();
  }

  return 0;
}
