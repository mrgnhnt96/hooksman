import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:git_hooks/mixins/paths_mixin.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class RegisterCommand extends Command<int> with PathsMixin {
  RegisterCommand({
    required this.fs,
    required this.logger,
    required this.git,
  });

  @override
  final Logger logger;
  @override
  final FileSystem fs;
  final GitService git;

  @override
  String get description => 'Register git hooks';

  @override
  String get name => 'register';

  @override
  FutureOr<int>? run() async {
    final root = this.root;

    if (root == null) {
      logger.err('Could not find root directory');
      return 1;
    }

    final definedHooksDir = fs.directory(fs.path.join(root, 'hooks'));

    if (!definedHooksDir.existsSync()) {
      logger.err('No hooks defined');
      return 1;
    }

    final definedHooks =
        definedHooksDir.listSync(followLinks: false).whereType<File>().toList();

    if (definedHooks.isEmpty) {
      logger.err('No hooks to register');
      return 1;
    }

    logger.detail('Registering hooks (${definedHooks.length})');

    final hooksDartToolDir =
        fs.directory(fs.path.join(root, '.dart_tool', 'git_hooks'));
    final executables = fs
        .directory(fs.path.join(hooksDartToolDir.path, 'executables'))
      ..createSync(recursive: true);

    final hooks = <String>[];
    final toCompile = <Future<void>>[];

    for (final hook in definedHooks) {
      final relativePath =
          fs.path.relative(hook.path, from: hooksDartToolDir.path);

      final content = '''
import 'package:git_hooks/git_hooks.dart';

import '$relativePath' as hook;

Future<int> main() async {
  return await executeHook(hook.main());
}''';

      final file = fs.file(fs.path.join(hooksDartToolDir.path, hook.basename))
        ..writeAsStringSync(content);

      logger.detail('Registered hook: ${hook.basename}');

      final outFile =
          executables.childFile(p.basenameWithoutExtension(file.path));

      hooks.add(outFile.path);

      final process = Process.run('dart', [
        'compile',
        'exe',
        file.path,
        '-o',
        outFile.path,
      ]);

      toCompile.add(process);
    }

    final progress = logger.progress('Compiling executables');

    await Future.wait(toCompile);

    progress.complete();

    // move executables to .git/hooks
    final hooksPath = this.hooksDir;

    if (hooksPath == null) {
      logger.err('Could not find .git/hooks directory');
      return 1;
    }

    final hooksDir = fs.directory(hooksPath);

    if (hooksDir.existsSync()) {
      hooksDir.deleteSync(recursive: true);
    }

    final execsDir = fs.directory(fs.path.join(hooksPath, 'execs'))
      ..createSync(recursive: true);

    for (final hook in hooks) {
      final name = p.basename(hook).toParamCase();
      fs.file(hook).copySync(fs.path.join(execsDir.path, name));

      final content = '''
#!/bin/sh

# GENERATED CODE - DO NOT MODIFY BY HAND

set -e

\$(dirname \$0)/execs/$name
''';

      fs.file(fs.path.join(hooksPath, name)).writeAsStringSync(content);

      final executableResult = await Process.run('chmod', ['u+x', hook]);

      if (executableResult.exitCode != 0) {
        logger
          ..err('Failed to register hook')
          ..detail('Error: ${executableResult.stderr}');
        return 1;
      }
    }

    return 0;
  }
}
