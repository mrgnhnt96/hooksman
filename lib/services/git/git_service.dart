import 'package:file/file.dart';
import 'package:hooksman/services/git/git_checks_mixin.dart';
import 'package:hooksman/services/git/git_context.dart';
import 'package:hooksman/services/git/git_context_setter.dart';
import 'package:hooksman/utils/process/process.dart';
import 'package:mason_logger/mason_logger.dart';

class GitService with GitChecksMixin {
  const GitService({
    required this.logger,
    required this.fs,
    required this.debug,
    required this.process,
    required this.remoteName,
    required this.remoteUrl,
  });

  @override
  final Logger logger;
  final FileSystem fs;
  @override
  final Process process;
  final String? remoteName;
  final String? remoteUrl;

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
    final gitDir = process.sync(
      'git',
      [
        'rev-parse',
        '--git-dir',
      ],
    );

    return gitDir.stdout.trim();
  }

  Future<bool> setHooksDir() async {
    final gitDir = this.gitDir;

    final hooksDir = fs.directory(fs.path.join(gitDir, 'hooks'));

    if (!hooksDir.existsSync()) {
      hooksDir.createSync(recursive: true);
    }

    final result = await process.run('git', [
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

    final out = result.stdout.trim();

    final files =
        out.split('\x00').where((element) => element.isNotEmpty).toList();

    if (remoteName case final String remoteName
        when files.isEmpty && diffArgs.contains('@{u}')) {
      final currentBranch = await getCurrentBranch();

      final upstream = '$remoteName/$currentBranch';

      return diffFiles(
        diffArgs: [
          for (final arg in diffArgs)
            if (arg == '@{u}') upstream else arg,
        ],
        diffFilters: diffFilters,
      );
    }

    return files;
  }

  Future<String> getCurrentBranch() async {
    final result = await process.run('git', [
      'rev-parse',
      '--abbrev-ref',
      'HEAD',
    ]);

    final branch = result.stdout.trim();

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

    final out = status.stdout;

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
    await process.run('git', [
      'add',
      '--',
      ...filePaths,
    ]);
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
