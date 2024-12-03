import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:git_hooks/mixins/paths_mixin.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

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
    final executablesDir = fs
        .directory(fs.path.join(hooksDartToolDir.path, 'executables'))
      ..createSync(recursive: true);

    final executables = <String>[];
    final toCompile = <Future<ProcessResult>>[];

    for (final hook in definedHooks) {
      final relativePath =
          fs.path.relative(hook.path, from: hooksDartToolDir.path);
      final content = '''
import 'package:git_hooks/git_hooks.dart';

import '$relativePath' as hook;

void main() {
  executeHook(hook.main());
}''';

      final file = fs.file(fs.path.join(hooksDartToolDir.path, hook.basename))
        ..writeAsStringSync(content);

      logger.detail('Registered hook: ${hook.basename}');

      final outFile =
          executablesDir.childFile(fs.path.basenameWithoutExtension(file.path));

      executables.add(outFile.path);

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

    final results = await Future.wait(toCompile);

    for (final result in results) {
      if (result.exitCode != 0) {
        progress.fail('Failed to compile ${result.stderr}');
        return 1;
      }
    }

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

    for (final exe in executables) {
      final name = fs.path.basename(exe).toParamCase();
      fs.file(exe).copySync(fs.path.join(hooksDir.path, name));
    }

    return 0;
  }
}
