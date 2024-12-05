import 'dart:io';

import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';

class GitService {
  const GitService({
    required this.logger,
    required this.fs,
  });

  final Logger logger;
  final FileSystem fs;

  Future<List<String>?> getChangedFiles(List<String> diff) async {
    const gitDiffArgs = [
      '--name-only',
      '--binary', // support binary files
      '--unified=0', // do not add lines around diff for consistent behavior
      '--no-color', // disable colors for consistent behavior
      '--no-ext-diff', // disable external diff tools for consistent behavior
      '--src-prefix=a/', // force prefix for consistent behavior
      '--dst-prefix=b/', // force prefix for consistent behavior
      '--patch', // output a patch that can be applied
      '--submodule=short', // always use the default short format for submodules
      '--diff-filter=ACMRT', // added, copied, modified, renamed, or type change
    ];

    final result = await Process.run('git', [
      'diff',
      if (diff.isEmpty) '--staged' else ...diff,
      'HEAD',
      ...gitDiffArgs,
    ]);

    // TODO(mrgnhnt): Handle error:
    /*
    fatal: ambiguous argument 'HEAD': unknown revision or path not in
    the working tree.
Use '--' to separate paths from revisions, like this:
'git <command> [<revision>...] -- [<file>...]'
     */

    if (result.exitCode != 0) {
      logger
        ..err('Failed to get changed files')
        ..detail('Error: ${result.stderr}');
      return null;
    }

    final out = result.stdout;

    if (out is! String) {
      logger
        ..err('Failed to get changed files')
        ..detail('Error: ${result.stderr}');
      return null;
    }

    final files =
        out.split('\n').where((element) => element.isNotEmpty).toList();

    return files;
  }

  Future<bool> isGitInstalled() async {
    final result = await Process.run('git', ['--version']);

    if (result.exitCode != 0) {
      logger
        ..err('Git is not installed')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return true;
  }

  Future<bool> isGitRepository() async {
    final result =
        await Process.run('git', ['rev-parse', '--is-inside-work-tree']);

    if (result.exitCode != 0) {
      logger
        ..err('Not a git repository')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return true;
  }

  Future<bool> hasAtLeastOneCommit() async {
    final result = await Process.run('git', ['rev-list', '--count', 'HEAD']);

    if (result.exitCode != 0) {
      logger
        ..err('Failed to get commit count')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    final count = int.tryParse(result.stdout as String);

    return count != null && count > 0;
  }

  Future<bool> isClean() async {
    final result = await Process.run('git', ['status', '--porcelain']);

    if (result.exitCode != 0) {
      logger
        ..err('Failed to get git status')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    final out = result.stdout;

    if (out is! String) {
      logger
        ..err('Failed to get git status')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return out.isEmpty;
  }
}
