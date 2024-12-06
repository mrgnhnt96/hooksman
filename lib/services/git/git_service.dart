import 'dart:io';

import 'package:file/file.dart';
import 'package:git_hooks/services/git/git_checks_mixin.dart';
import 'package:git_hooks/services/git/git_context.dart';
import 'package:git_hooks/services/git/git_context_setter.dart';
import 'package:git_hooks/services/git/merge_mixin.dart';
import 'package:git_hooks/services/git/patch_mixin.dart';
import 'package:git_hooks/services/git/stash_mixin.dart';
import 'package:mason_logger/mason_logger.dart';

class GitService with MergeMixin, GitChecksMixin, StashMixin, PatchMixin {
  const GitService({
    required this.logger,
    required this.fs,
  });

  @override
  final Logger logger;
  @override
  final FileSystem fs;

  @override
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

  @override
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
    List<String> files, {
    bool includeRenameFrom = true,
  }) {
    final flattened = <String>[];
    final renameRegExp = RegExp(' -> ');

    for (final file in files) {
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
    List<String> diffArgs = const [],
    String? diffFilters,
  }) async {
    final filters = switch (diffFilters) {
      final String filters => filters,
      _ => 'ACMR',
    };

    final diff = switch (diffArgs) {
      _ when diffArgs.isNotEmpty => diffArgs,
      _ => ['--staged'],
    };
    final result = await Process.run('git', [
      'diff',
      'HEAD',
      '--name-only',
      ...diff,
      '--diff-filter=$filters',
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
        .split('\x00')
        .where((line) {
          if (line.length < 2) return false;

          final [index, workingTree, ...] = line.split('');

          // index != ' ' && workingTree != ' '
          final isPartiallyStaged = index != ' ' && workingTree != ' ';

          // index != '?' && workingTree != '?';
          final isUntracked = index == '?' && workingTree == '?';

          return isPartiallyStaged && !isUntracked;
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

  /// Prepare files for the task.
  /// If [backup] is true, stash the current state of the repository.
  /// Returns a [GitContext] object with the current state of the repository.
  Future<GitContext> prepareFiles({
    bool backup = true,
  }) async {
    final context = GitContextSetter();

    try {
      context.partiallyStagedFiles = await partiallyStagedFiles();

      if (context.partiallyStagedFiles case final partially
          when partially.isNotEmpty) {
        final files = processRenames(partially);

        logger.detail('Creating patch');
        await patch(files);
      }

      if (!backup) {
        return context.toImmutable();
      }

      context
        ..mergeHead = mergeHead
        ..mergeMode = mergeMode
        ..mergeMsg = mergeMsg
        ..deletedFiles = await getDeletedFiles()
        ..stashHash = await createStash()
        ..nonStagedFiles = await nonStagedFiles() ?? []
        ..hidePartiallyStaged = backup;
    } catch (e) {
      logger
        ..err('Failed to prepare files')
        ..detail('Error: $e');
      throw Exception('Failed to prepare files');
    }

    return context.toImmutable();
  }

  Future<void> checkoutFiles(List<String> files) async {
    final processed = processRenames(files);

    await Process.run('git', [
      'checkout',
      '--force',
      '--',
      ...processed,
    ]);
  }

  Future<void> add(List<String> files) async {
    await Process.run('git', [
      'add',
      '--',
      ...files,
    ]);
  }

  Future<void> applyModifications(List<String> existing) async {
    final changedFiles = await nonStagedFiles();

    if (changedFiles == null || changedFiles.isEmpty) {
      return;
    }

    final difference = existing.toSet().difference(changedFiles.toSet());

    await add(difference.toList());
  }

  Future<bool> restoreStash() async {
    final stashIndex = await stash();

    if (stashIndex == null) {
      return false;
    }

    // hard reset
    final reset = await Process.run('git', [
      'reset',
      '--hard',
      'HEAD',
    ]);

    if (reset.exitCode != 0) {
      logger
        ..err('Failed to reset')
        ..detail('Error: ${reset.stderr}');
      return false;
    }

    // apply stash
    final apply = await Process.run('git', [
      'stash',
      'apply',
      '--quiet',
      '--index',
      '$stashIndex',
    ]);

    if (apply.exitCode != 0) {
      logger
        ..err('Failed to apply stash')
        ..detail('Error: ${apply.stderr}');
      return false;
    }

    return true;
  }

  Future<void> ensureDeletedFiles(List<String> deletedFiles) async {
    for (final path in deletedFiles) {
      final file = fs.file(path);

      if (file.existsSync()) continue;

      file.deleteSync();
    }
  }
}
