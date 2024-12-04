import 'dart:async';
import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:git_hooks/mixins/paths_mixin.dart';
import 'package:git_hooks/models/compiler.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

class RegisterCommand extends Command<int> with PathsMixin {
  RegisterCommand({
    required this.fs,
    required this.logger,
    required this.git,
    required this.compiler,
  });

  @override
  final Logger logger;
  @override
  final FileSystem fs;
  final GitService git;
  final Compiler compiler;

  @override
  String get description => 'Register git hooks';

  @override
  String get name => 'register';

  (List<File>, int?) definedHooks(String root) {
    final definedHooksDir = fs.directory(fs.path.join(root, 'hooks'));

    if (!definedHooksDir.existsSync()) {
      logger.err('No hooks defined');
      return ([], 1);
    }

    final definedHooks =
        definedHooksDir.listSync(followLinks: false).whereType<File>().toList();

    if (definedHooks.isEmpty) {
      logger.err('No hooks to register');
      return ([], 1);
    }

    return (definedHooks, null);
  }

  Iterable<
      ({
        String executablePath,
        Future<ProcessResult> process,
      })> prepareExecutables(
    List<File> definedHooks, {
    required Directory hooksDartToolDir,
    required Directory executablesDir,
  }) sync* {
    if (hooksDartToolDir.existsSync()) {
      hooksDartToolDir.deleteSync(recursive: true);
    }
    if (!executablesDir.existsSync()) {
      executablesDir.createSync(recursive: true);
    }

    for (final hook in definedHooks) {
      final relativePath =
          fs.path.relative(hook.path, from: hooksDartToolDir.path);

      final hookName =
          fs.path.basenameWithoutExtension(hook.path).toParamCase();

      final content = '''
import 'package:git_hooks/git_hooks.dart';

import '$relativePath' as hook;

void main() {
  executeHook('$hookName', hook.main());
}''';

      final file = fs.file(fs.path.join(hooksDartToolDir.path, hook.basename))
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

      logger.detail('Registered hook: ${hook.basename}');

      final outFile = executablesDir
          .childFile(fs.path.basenameWithoutExtension(file.path).toParamCase());

      final process = compiler.compile(
        file: file.path,
        outFile: outFile.path,
      );

      yield (executablePath: outFile.path, process: process);
    }
  }

  int copyExecutables(
    List<String> executables, {
    required String gitHooksDir,
  }) {
    final hooksDir = fs.directory(gitHooksDir);

    if (!hooksDir.existsSync()) {
      hooksDir.createSync(recursive: true);
    }

    for (final exe in executables) {
      final name = fs.path.basename(exe).toParamCase();
      fs.file(exe).copySync(fs.path.join(hooksDir.path, name));
    }

    return 0;
  }

  Future<List<String>?> compile(
    Iterable<({String executablePath, Future<ProcessResult> process})>
        executablesToCompile,
    void Function(String) fail,
  ) async {
    final (paths: executables, processes: toCompile) = executablesToCompile
        .fold((paths: <String>[], processes: <Future<ProcessResult>>[]),
            (acc, e) {
      return acc
        ..paths.add(e.executablePath)
        ..processes.add(e.process);
    });

    final results = await Future.wait(toCompile);

    for (final result in results) {
      if (result.exitCode != 0) {
        fail('Failed to compile ${result.stderr}');
        return null;
      }
    }

    return executables;
  }

  @override
  FutureOr<int>? run() async {
    final root = this.root;
    if (root == null) {
      logger.err('Could not find root directory');
      return 1;
    }

    final (definedHooks, exitCode) = this.definedHooks(root);

    if (exitCode case final int code) {
      return code;
    }

    logger.detail('Registering hooks (${definedHooks.length})');

    final hooksDartToolDir = dartToolGitHooksDir(root);
    final executablesDir = this.executablesDir(root);

    final progress = logger.progress('Compiling executables');

    final executablesToCompile = prepareExecutables(
      definedHooks,
      hooksDartToolDir: hooksDartToolDir,
      executablesDir: executablesDir,
    );

    final executables = await compile(executablesToCompile, progress.fail);

    if (executables == null) {
      return 1;
    }

    progress.complete();

    // move executables to .git/hooks
    final hooksPath = gitHooksDir;

    if (hooksPath == null) {
      logger.err('Could not find .git/hooks directory');
      return 1;
    }

    return copyExecutables(executables, gitHooksDir: hooksPath);
  }
}
