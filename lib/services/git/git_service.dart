import 'package:hooksman/deps/args.dart';
import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';
import 'package:hooksman/services/git/git_checks_mixin.dart';
import 'package:hooksman/services/git/git_context.dart';
import 'package:hooksman/services/git/git_context_setter.dart';

class GitService with GitChecksMixin {
  const GitService({this.remoteName, this.remoteUrl});

  final String? remoteName;
  final String? remoteUrl;

  bool get debug => args['loud'] == true;

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
    final gitDir = process.sync('git', ['rev-parse', '--git-dir']);

    return switch (gitDir.stdout) {
      final String out => out.trim(),
      _ => throw Exception('Failed to get git directory'),
    };
  }

  /// Points Git at the managed shim directory (`hooks/_`), husky-style.
  ///
  /// Uses a project-relative path so clones work without re-configuring
  /// absolute paths. User sources stay in `hooks/*.dart|*.sh`; Git never
  /// writes into `.git/hooks`.
  Future<bool> setHooksDir() async {
    final result = await process.run('git', [
      'config',
      '--local',
      'core.hooksPath',
      'hooks/_',
    ]);

    if (result.exitCode != 0) {
      logger
        ..err('Failed to set hooks directory')
        ..detail('Error: ${result.stderr}');

      return false;
    }

    return true;
  }

  /// Unsets `core.hooksPath` so Git falls back to `.git/hooks`.
  ///
  /// Exit code 5 means the key was not set — treated as success.
  Future<bool> unsetHooksDir() async {
    final result = await process.run('git', [
      'config',
      '--local',
      '--unset',
      'core.hooksPath',
    ]);

    final code = result.exitCode;
    if (code != 0 && code != 5) {
      logger
        ..err('Failed to unset hooks directory')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return true;
  }

  Future<List<String>> stagedFiles() async {
    return await diffFiles(diffArgs: ['HEAD', '--staged'], diffFilters: 'ACMR');
  }

  Future<List<String>> nonStagedFiles() async {
    return await diffFiles(diffArgs: [], diffFilters: 'ACMR');
  }

  Future<List<String>> deletedFiles() async {
    return await diffFiles(diffArgs: ['HEAD'], diffFilters: 'D');
  }

  Future<List<String>> diffFiles({
    required List<String> diffArgs,
    required String diffFilters,
  }) async {
    final result = await process.run('git', [
      'diff',
      ...diffArgs,
      if (diffFilters.isNotEmpty) '--diff-filter=$diffFilters',
      '--name-only',
      '-z',
    ]);

    if (result.exitCode != 0) {
      // Missing upstream / failed `@{u}` should not fail the hook — treat as
      // no files (e.g. first push of a branch with no remote tracking ref).
      if (diffArgs.contains('@{u}')) {
        if (remoteName case final String remoteName) {
          final currentBranch = await getCurrentBranch();
          final upstream = '$remoteName/$currentBranch';

          logger.detail('git diff with @{u} failed; retrying with $upstream');

          return diffFiles(
            diffArgs: [
              for (final arg in diffArgs)
                if (arg == '@{u}') upstream else arg,
            ],
            diffFilters: diffFilters,
          );
        }

        logger.detail(
          'git diff with @{u} failed and no remote was provided; '
          'treating as empty file list',
        );
        return [];
      }

      logger.detail(
        'git diff failed (exit ${result.exitCode}); treating as empty. '
        'stderr: ${result.stderr}',
      );
      return [];
    }

    final out = switch (result.stdout) {
      final String out => out.trim(),
      final Future<String> out => (await out).trim(),
    };

    return out.split('\x00').where((element) => element.isNotEmpty).toList();
  }

  Future<String> getCurrentBranch() async {
    final result = await process.run('git', [
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    ]);

    final branch = switch (result.stdout) {
      final String out => out.trim(),
      final Future<String> out => (await out).trim(),
    };

    return branch;
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

  // Get a list of files with both staged and unstaged changes.
  // Unstaged changes to these files should be hidden before the tasks run.
  Future<List<String>> partiallyStagedFiles() async {
    final status = await process.run('git', ['status', '-z']);
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

    final out = switch (status.stdout) {
      final String out => out,
      final Future<String> out => (await out),
    };

    final partiallyStaged = out
        .split(RegExp('\x00(?=[ AMDRCU?!])'))
        .where((line) {
          if (line.length < 2) return false;

          final [staged, workingTree, ...] = line.split('');

          return staged != ' ' &&
              workingTree != ' ' &&
              staged != '?' &&
              workingTree != '?';
        })
        .map((line) => line.substring(3))
        .where((element) => element.isNotEmpty)
        .toList();

    return partiallyStaged;
  }

  Future<GitContext> prepareFiles() async {
    final context = GitContextSetter();

    try {
      context.partiallyStagedFiles = await partiallyStagedFiles();

      if (context.partiallyStagedFiles case final partially
          when partially.isNotEmpty) {
        logger.detail(
          'Preparing partial files for patch (${partially.length})',
        );
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
        ..deletedFiles = await deletedFiles()
        ..nonStagedFiles = await nonStagedFiles();
    } catch (e) {
      logger
        ..err('Failed to prepare files')
        ..detail('Error: $e');
      throw Exception('Failed to prepare files');
    }

    return context;
  }

  Future<void> add(List<String> filePaths) async {
    await process.run('git', ['add', '--', ...filePaths]);
  }

  Future<void> applyModifications(List<String> existing) async {
    logger.detail('Checking for modifications');
    final changed = await nonStagedFiles();
    final allDeletedFiles = await deletedFiles();

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

    final deleted = allDeletedFiles.toSet().difference(existing.toSet());
    logger.detail('Found ${deleted.length} deleted files to add');
    for (final file in deleted) {
      logger.detail('  - $file');
    }

    final filesToAdd = modifiedFiles.followedBy(deleted);
    if (filesToAdd.isEmpty) {
      logger.detail('Nothing to add to commit');
      return;
    }

    await add(filesToAdd.toList());
  }
}
