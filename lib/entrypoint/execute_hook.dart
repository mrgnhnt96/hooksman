import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:git_hooks/models/dart_script.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/models/shell_script.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

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
    exitCode = await run(
      hook,
      logger: logger,
      gitService: gitService,
      resolver: resolver,
    );
  } catch (e) {
    exitCode = 1;
  }
}

Future<int> run(
  Hook hook, {
  required Logger logger,
  required GitService gitService,
  required Resolver resolver,
}) async {
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

  for (final (files, command) in resolvedHook.commands) {
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
    return await runZoned(
      () async {
        return await script.script(files);
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) {
          // don't print anything
        },
      ),
    );
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
