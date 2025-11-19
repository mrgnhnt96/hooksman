import 'dart:async';
import 'dart:io';

import 'package:change_case/change_case.dart';
import 'package:file/file.dart';
import 'package:glob/glob.dart';
import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/compiler.dart';
import 'package:hooksman/deps/fs.dart';
import 'package:hooksman/deps/git.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/mixins/paths_mixin.dart';
import 'package:hooksman/models/defined_hook.dart';
import 'package:mason_logger/mason_logger.dart';

const _usage = '''
Usage: hooksman register

Register git hooks
''';

class RegisterCommand with PathsMixin {
  const RegisterCommand();

  (List<DefinedHook>, int?) definedHooks(String root) {
    final definedHooksDir = fs.directory(fs.path.join(root, 'hooks'));

    if (!definedHooksDir.existsSync()) {
      logger.err('No hooks defined');
      return ([], 1);
    }

    final dartGlob = Glob('*.dart');
    final dartFound =
        dartGlob.listFileSystemSync(fs, root: definedHooksDir.path);

    final shellGlob = Glob('*.sh');
    final shellFound =
        shellGlob.listFileSystemSync(fs, root: definedHooksDir.path);

    final definedHooks = [
      for (final entity in dartFound)
        if (entity is File) DefinedHook(entity.path),
      for (final entity in shellFound)
        if (entity is File) DefinedHook(entity.path),
    ];

    if (definedHooks.isEmpty) {
      logger.err('No hooks to register');
      return ([], 1);
    }

    final s = definedHooks.length > 1 ? 's' : '';
    logger.info(green.wrap('Found ${definedHooks.length} hook$s'));
    for (final hook in definedHooks) {
      logger.info(darkGray.wrap('  - ${fs.path.basename(hook.fileName)}'));
    }
    logger.write('\n');

    return (definedHooks, null);
  }

  Iterable<
      ({
        String executablePath,
        Future<ProcessResult> process,
      })> prepareExecutables(
    List<DefinedHook> definedHooks, {
    required Directory hooksDartToolDir,
    required Directory executablesDir,
  }) sync* {
    if (hooksDartToolDir.existsSync()) {
      hooksDartToolDir.deleteSync(recursive: true);
    }
    executablesDir.createSync(recursive: true);

    logger.info(yellow.wrap('Preparing hooks'));

    for (final hook in definedHooks.where((e) => e.isDart)) {
      final relativePath =
          fs.path.relative(hook.path, from: hooksDartToolDir.path);

      final content = '''
import 'package:hooksman/hooksman.dart';

import '$relativePath' as hook;

void main(List<String> args) {
  executeHook('${hook.name}', hook.main(), args);
}''';

      final file = fs.file(
        fs.path.join(hooksDartToolDir.path, fs.path.basename(hook.fileName)),
      )
        ..createSync(recursive: true)
        ..writeAsStringSync(content);

      logger.info(darkGray.wrap('  - ${hook.name}'));

      final outFile = executablesDir.childFile(hook.name);

      final process = compiler.compile(
        file: file.path,
        outFile: outFile.path,
      );

      yield (executablePath: outFile.path, process: process);
    }

    for (final hook in definedHooks.where((e) => e.isShell)) {
      logger.info(darkGray.wrap('  - ${hook.name}'));

      final outFile = executablesDir.childFile(hook.name);

      final process = compiler.prepareShellExecutable(
        file: hook.path,
        outFile: outFile.path,
      );

      yield (executablePath: outFile.path, process: process);
    }

    logger.write('\n');
  }

  int copyExecutables(
    List<String> executables, {
    required String gitHooksDir,
  }) {
    final hooksDir = fs.directory(gitHooksDir);

    if (hooksDir.existsSync()) {
      // delete existing hooks, to reset any removed hooks
      hooksDir.deleteSync(recursive: true);
    }

    hooksDir.createSync(recursive: true);

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

  Future<int?> setHooksPath() async {
    try {
      final success = await git.setHooksDir();

      if (!success) {
        throw Exception('Could not set hooks path');
      }
    } catch (e) {
      logger
        ..err('Could not set hooks path')
        ..detail(e.toString());
      return 1;
    }

    return null;
  }

  Future<int> run() async {
    if (args['help'] case true) {
      logger.write(_usage);
      return 0;
    }

    if (await setHooksPath() case final int code) {
      return code;
    }

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

    final progress = logger.progress('Registering hooks');

    final executablesToCompile = prepareExecutables(
      definedHooks,
      hooksDartToolDir: hooksDartToolDir,
      executablesDir: executablesDir,
    );

    final executables = await compile(executablesToCompile, progress.fail);
    if (executables == null) {
      return 1;
    }

    final hooksPath = gitHooksDir;
    if (hooksPath == null) {
      logger.err('Could not find .git/hooks directory');
      return 1;
    }

    if (copyExecutables(executables, gitHooksDir: hooksPath) case final int code
        when code != 0) {
      return code;
    }

    progress.complete('Registered hooks');

    return 0;
  }
}
