import 'dart:io';

import 'package:file/file.dart';
import 'package:hooksman/services/git/git_checks_mixin.dart';
import 'package:hooksman/services/git/git_context.dart';
import 'package:hooksman/services/git/git_context_setter.dart';
import 'package:mason_logger/mason_logger.dart';

class GitService with GitChecksMixin {
  const GitService({
    required this.logger,
    required this.fs,
    required this.debug,
  });

  @override
  final Logger logger;
  final FileSystem fs;

  final bool debug;

  List<String> get gitDiffArgs => [
        // support binary files
        '--binary',
        // do not add lines around diff for consistent behavior
        '--unified=0',
        // disable colors for consistent behavior
        '--no-color',
        // disable external diff tools for consistent behavior
        '--no-ext-diff',
        // force prefix for consistent behavior
        '--src-prefix=a/',
        // force prefix for consistent behavior
        '--dst-prefix=b/',
        // output a patch that can be applied
        '--patch',
        // always use the default short format for submodules
        '--submodule=short',
      ];

  String get gitDir {
    final gitDir = Process.runSync(
      'git',
      [
        'rev-parse',
        '--git-dir',
      ],
    );

    return switch (gitDir.stdout) {
      final String dir => dir.trim(),
      _ => throw Exception('Failed to get git directory'),
    };
  }

  Future<bool> setHooksDir() async {
    final gitDir = this.gitDir;

    final hooksDir = fs.directory(fs.path.join(gitDir, 'hooks'));

    if (!hooksDir.existsSync()) {
      hooksDir.createSync(recursive: true);
    }

    final result = await Process.run('git', [
      'config',
      '--local',
      'core.hooksPath',
      hooksDir.path,
    ]);

    if (result.exitCode != 0) {
      logger
        ..err('Failed to set hooks directory')
        ..detail('Error: ${result.stderr}');

      return false;
    }

    return true;
  }

  Future<List<String>?> stagedFiles() async {
    final result = await Process.run('git', [
      'diff',
      'HEAD',
      '--staged',
      '--diff-filter=ACMR',
    ]);

    final out = switch (result.stdout) {
      final String files => files.trim(),
      _ => null,
    };

    if (out == null) {
      logger
        ..err('Failed to get changed files')
        ..detail('Error: ${result.stderr}');
      return null;
    }

    final files =
        out.split('\n').where((element) => element.isNotEmpty).toList();

    return files;
  }

  Future<List<String>?> nonStagedFiles() async {
    final result = await Process.run('git', [
      'diff',
      '--name-only',
      '-z',
      '--diff-filter=ACMR',
    ]);

    final out = switch (result.stdout) {
      final String files => files.trim(),
      _ => null,
    };

    if (out == null) {
      logger
        ..err('Failed to get non-staged files')
        ..detail('Error: ${result.stderr}');
      return null;
    }

    final allFiles =
        out.split('\x00').where((element) => element.isNotEmpty).toList();

    return allFiles;
  }

  /// From list of files, split renames and flatten into
  /// two files `to`NUL`from`.
  ///
  /// [includeRenameFrom] Whether or not to include the
  /// `from` renamed file, which is no longer on disk
  List<String> processRenames(
    List<String> filePaths, {
    bool includeRenameFrom = true,
  }) {
    final flattened = <String>[];
    final renameRegExp = RegExp('/\x00/');

    for (final file in filePaths) {
      if (renameRegExp.hasMatch(file)) {
        final parts = file.split(renameRegExp);
        if (parts.length < 2) {
          logger
            ..err('Failed to process rename')
            ..detail('File: $file');
          continue;
        }

        final [to, from, ...] = parts;
        if (includeRenameFrom) flattened.add(from);
        flattened.add(to);
      } else {
        flattened.add(file);
      }
    }

    return flattened;
  }

  Future<List<String>?> diffFiles({
    required List<String> diffArgs,
    required String diffFilters,
  }) async {
    final diff = {...diffArgs, '--name-only'};

    final result = await Process.run('git', [
      'diff',
      ...diff,
      if (diffFilters.isNotEmpty) '--diff-filter=$diffFilters',
    ]);

    final out = switch (result.stdout) {
      final String files => files.trim(),
      _ => null,
    };

    if (out == null) {
      logger
        ..err('Failed to get changed files')
        ..detail('Error: ${result.stderr}');
      return null;
    }

    final files =
        out.split('\n').where((element) => element.isNotEmpty).toList();

    return files;
  }

  // Get a list of files with both staged and unstaged changes.
  // Unstaged changes to these files should be hidden before the tasks run.
  Future<List<String>> partiallyStagedFiles() async {
    final status = await Process.run('git', ['status', '-z']);
    // See https://git-scm.com/docs/git-status#_short_format
    // Entries returned in machine format are separated by a NUL character.
    // The first letter of each entry represents current index status,
    // and second the working tree. Index and working tree status codes are
    // separated from the file name by a space. If an entry includes a
    // renamed file, the file names are separated by a NUL character
    // (e.g. `to`\0`from`)

    if (status.exitCode != 0) {
      logger
        ..err('Failed to get git status')
        ..detail('Error: ${status.stderr}');
      return [];
    }

    final out = status.stdout;
    if (out is! String) {
      logger
        ..err('Failed to get git status')
        ..detail('Error: ${status.stderr}');
      return [];
    }

    final partiallyStaged = out
        .split(RegExp('\x00(?=[ AMDRCU?!])'))
        .where((line) {
          if (line.length < 2) return false;

          final [index, workingTree, ...] = line.split('');

          return index != ' ' &&
              workingTree != ' ' &&
              index != '?' &&
              workingTree != '?';
        })
        .map((line) => line.substring(3))
        .where((element) => element.isNotEmpty)
        .toList();

    return partiallyStaged;
  }

  Future<List<String>> getDeletedFiles() async {
    final result = await Process.run('git', [
      'diff',
      'HEAD',
      '--name-only',
      '--diff-filter=D',
      ...gitDiffArgs,
    ]);

    final out = switch (result.stdout) {
      final String files => files.trim(),
      _ => '',
    };

    final files =
        out.split('\n').where((element) => element.isNotEmpty).toList();

    return files;
  }

  Future<GitContext> prepareFiles() async {
    final context = GitContextSetter();

    try {
      context.partiallyStagedFiles = await partiallyStagedFiles();

      if (context.partiallyStagedFiles case final partially
          when partially.isNotEmpty) {
        logger
            .detail('Preparing partial files for patch (${partially.length})');
        for (final file in partially) {
          logger.detail('  $file');
        }
        final filePaths = processRenames(partially);

        logger.detail('Processed files (${partially.length})');
        for (final file in filePaths) {
          logger.detail('  $file');
        }
      }

      context
        ..deletedFiles = await getDeletedFiles()
        ..nonStagedFiles = await nonStagedFiles() ?? [];
    } catch (e) {
      logger
        ..err('Failed to prepare files')
        ..detail('Error: $e');
      throw Exception('Failed to prepare files');
    }

    return context;
  }

  Future<void> add(List<String> filePaths) async {
    await Process.run('git', [
      'add',
      '--',
      ...filePaths,
    ]);
  }

  Future<void> applyModifications(List<String> existing) async {
    if (!await hasAtLeastOneCommit()) {
      return;
    }

    logger.detail('Checking for modifications');
    final changed = await nonStagedFiles() ?? [];
    final allDeletedFiles = await getDeletedFiles();

    if (changed.isEmpty && allDeletedFiles.isEmpty) {
      logger.detail('No post file modifications were found');
      return;
    }

    logger.detail('Pre-Task files: (${existing.length})');
    for (final file in existing) {
      logger.detail('  - $file');
    }

    logger.detail('Post-Task files: (${changed.length})');
    for (final file in changed) {
      logger.detail('  - $file');
    }

    logger.detail('Post-Deleted Files (${allDeletedFiles.length})');
    for (final file in allDeletedFiles) {
      logger.detail('  - $file');
    }

    final modifiedFiles = changed.toSet().difference(existing.toSet());
    logger.detail('Found ${modifiedFiles.length} files modified or created');
    for (final file in modifiedFiles) {
      logger.detail('  - $file');
    }

    final deletedFiles = allDeletedFiles.toSet().difference(existing.toSet());
    logger.detail('Found ${deletedFiles.length} deleted files to add');
    for (final file in deletedFiles) {
      logger.detail('  - $file');
    }

    final filesToAdd = modifiedFiles.followedBy(deletedFiles);
    if (filesToAdd.isEmpty) {
      logger.detail('Nothing to add to commit');
      return;
    }

    await add(filesToAdd.toList());
  }
}
