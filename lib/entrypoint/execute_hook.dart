import 'dart:async';
import 'dart:io';

import 'package:file/local.dart';
import 'package:git_hooks/models/dart_script.dart';
import 'package:git_hooks/models/hook.dart';
import 'package:git_hooks/models/hook_command.dart';
import 'package:git_hooks/models/resolver.dart';
import 'package:git_hooks/models/resolving_tasks.dart';
import 'package:git_hooks/models/shell_script.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:git_hooks/utils/multi_line_progress.dart';
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

String label(
  List<ResolvingTask> tasks, {
  required String name,
  required String frame,
}) {
  // get width of terminal
  final maxWidth = stdout.terminalColumns;
  final down = yellow.wrap('↓');
  final right = yellow.wrap('→');
  final dot = yellow.wrap('•');
  final loading = yellow.wrap(frame);
  final checkMark = green.wrap('✔️');
  final x = red.wrap('❌');

  String? fileCount(int count) {
    final string = switch (count) {
      0 => '- no files',
      1 => '- 1 file',
      _ => '- $count files',
    };

    return darkGray.wrap(string);
  }

  String? icon(
    HookCommand command,
    int fileCount, {
    required bool isComplete,
    required bool isError,
    required bool isHalted,
  }) {
    if (fileCount == 0) {
      return yellow.wrap(down);
    }

    if (isHalted) {
      return yellow.wrap(dot);
    }

    if (isError) {
      return red.wrap(x);
    }

    if (isComplete) {
      return green.wrap(checkMark);
    }

    final icon = switch (command) {
      ShellScript() => right,
      DartScript() => loading,
      _ => '',
    };

    return yellow.wrap(icon);
  }

  Iterable<String?> label() sync* {
    yield 'Running tasks for $name';
    for (final task in tasks) {
      final ResolvingTask(
        :command,
        :code,
        :hasCompleted,
        :isError,
        :isHalted,
        :files,
      ) = task;

      final count = fileCount(files.length);
      final iconString = icon(
        command,
        files.length,
        isComplete: hasCompleted,
        isError: isError,
        isHalted: isHalted,
      );

      yield '  $iconString ${command.resolvedName} $count';

      if (files.isEmpty) {
        continue;
      }

      if (command is! ShellScript) {
        continue;
      }

      if (hasCompleted) {
        continue;
      }

      for (final script in command.commands(files)) {
        yield '    $loading $script';
      }
    }

    yield '\n';
  }

  return label().map((e) {
    if (e == null) return null;
    final trimmed = e.split('').take(maxWidth).toList();

    if (trimmed.length < e.length) {
      trimmed.add('…');
    }

    return trimmed.join();
  }).join('\n');
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

  final resolvingTasks = <ResolvingTask>[];
  final tasks = <(ResolvingTask, Future<int>)>[];

  for (final (files, command) in resolvedHook.commands) {
    final future = switch (command) {
      ShellScript() => _runShellScript(command, files, logger),
      DartScript() => _runDartScript(command, files, logger),
      _ => throw ArgumentError(
          'Unsupported command type',
          command.runtimeType.toString(),
        ),
    };

    final task = ResolvingTask(
      files: files,
      command: command,
      completer: switch (files.length) {
        0 => null,
        _ => Completer<int>(),
      },
    );

    tasks.add((task, future));

    resolvingTasks.add(task);
  }

  if (resolvingTasks.every((e) => e.files.isEmpty)) {
    logger.info('No matching files');
    return 0;
  }

  logger.info('Got ${resolvingTasks.length} tasks to run');

  final progress = MultiLineProgress(
    createLabel: (frame) => label(
      resolvingTasks,
      name: hookName,
      frame: frame,
    ),
  )..start();

  for (final task in tasks) {
    final (completer, future) = task;

    future.then((code) {
      final (e, _) = task;

      e.code = code;

      if (code != 0) {
        for (final (task, _) in tasks) {
          task.kill();
        }
      }
    }).ignore();
  }

  final _ = await Future.wait(
    [
      for (final (task, _) in tasks) task.future,
    ].whereType(),
    eagerError: true,
  );

  await progress.closeNextFrame();

  logger
    ..flush()
    ..write('\n');

  for (final (task, _) in tasks) {
    if (task.code case final int code when code != 0) {
      return code;
    }
  }

  return 0;
}

Future<int> _runDartScript(
  DartScript script,
  Iterable<String> files,
  Logger logger,
) async {
  if (files.isEmpty) {
    return 0;
  }

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
    logger
      ..delayed(red.wrap('Error when running ${script.resolvedName}'))
      ..delayed('$e');

    return 1;
  }
}

Future<int> _runShellScript(
  ShellScript script,
  Iterable<String> files,
  Logger logger,
) async {
  for (final command in script.commands(files)) {
    final result = await Process.run(
      'bash',
      [
        '-c',
        command,
      ],
    );

    if (result.exitCode != 0) {
      logger
        ..delayed(result.stdout as String)
        ..delayed(result.stderr as String);
      return 1;
    }
  }

  return 0;
}
