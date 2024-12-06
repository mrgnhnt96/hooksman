import 'dart:io';

import 'package:file/file.dart';
import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart' as p;

class GitService {
  const GitService({
    required this.logger,
    required this.fs,
  });

  final Logger logger;
  final FileSystem fs;

  static const stashMessage = 'stash | git_hooks';
  static const hiddenPatch = '.git_hooks.patch';

  static const gitDiffArgs = [
    '--name-only',
    '--binary', // support binary files
    '--unified=0', // do not add lines around diff for consistent behavior
    '--no-color', // disable colors for consistent behavior
    '--no-ext-diff', // disable external diff tools for consistent behavior
    '--src-prefix=a/', // force prefix for consistent behavior
    '--dst-prefix=b/', // force prefix for consistent behavior
    '--patch', // output a patch that can be applied
    '--submodule=short', // always use the default short format for submodules
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
      final String dir => dir,
      _ => throw Exception('Failed to get git directory'),
    };
  }

  String? content(String path) {
    final file = fs.file(path);

    if (!file.existsSync()) return null;

    return file.readAsStringSync();
  }

  void writeContent(String path, String? content) {
    if (content == null) return;

    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync(content);
  }

  set mergeHead(String? content) =>
      writeContent(p.join(gitDir, 'MERGE_HEAD'), content);

  String? get mergeHead {
    return content(p.join(gitDir, 'MERGE_HEAD'));
  }

  set mergeMode(String? content) =>
      writeContent(p.join(gitDir, 'MERGE_MODE'), content);

  String? get mergeMode {
    return content(p.join(gitDir, 'MERGE_MODE'));
  }

  set mergeMsg(String? content) =>
      writeContent(p.join(gitDir, 'MERGE_MSG'), content);

  String? get mergeMsg {
    return content(p.join(gitDir, 'MERGE_MSG'));
  }

  String get hiddenFilePath {
    return p.join(gitDir, hiddenPatch);
  }

  Future<List<String>?> stagedFiles() async {
    final result = await Process.run('git', [
      'diff',
      'HEAD',
      '--staged',
      '--diff-filter=ACMR',
    ]);

    final out = switch (result.stdout) {
      final String files => files,
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
      ...diff,
      '--diff-filter=$filters',
    ]);

    final out = switch (result.stdout) {
      final String files => files,
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
      '--diff-filter=D',
      ...gitDiffArgs,
    ]);

    final out = switch (result.stdout) {
      final String files => files,
      _ => '',
    };

    final files =
        out.split('\n').where((element) => element.isNotEmpty).toList();

    return files;
  }

// Save stash of all staged files.
  // The `stash create` command creates a dangling
  // commit without removing any files,
  // and `stash store` saves it as an actual stash.
  Future<String?> createStash() async {
    final result = await Process.run('git', ['stash', 'create']);

    final hash = switch (result.stdout) {
      final String hash => hash,
      _ => null,
    };

    if (hash == null) {
      logger
        ..err('Failed to create stash')
        ..detail('Error: ${result.stderr}');
      return null;
    }

    final storeResult = await Process.run(
      'git',
      [
        'stash',
        'store',
        '-m',
        stashMessage,
        hash,
      ],
    );

    if (storeResult.exitCode != 0) {
      logger
        ..err('Failed to store stash')
        ..detail('Error: ${storeResult.stderr}');
      return null;
    }

    return hash;
  }

  Future<void> restoreGitFiles(
    List<String> files,
  ) async {
    final result = await Process.run(
      'git',
      [
        'diff',
        ...gitDiffArgs,
        '--output=$hiddenFilePath',
        '--',
        ...files,
      ],
    );

    if (result.exitCode != 0) {
      logger
        ..err('Failed to checkout files')
        ..detail('Error: ${result.stderr}');
    }
  }

  Future<GitContext> prepareFiles({
    bool backup = true,
  }) async {
    final context = GitContextSetter();

    try {
      context.partiallyStagedFiles = await partiallyStagedFiles();

      if (context.partiallyStagedFiles case final partially
          when partially.isNotEmpty) {
        final files = processRenames(partially);

        await restoreGitFiles(files);
      }

      if (!backup) {
        return context.toImmutable();
      }

      context
        ..mergeHead = mergeHead
        ..mergeMode = mergeMode
        ..mergeMsg = mergeMsg
        ..deletedFiles = await getDeletedFiles()
        ..stashHash = await createStash();
    } catch (e) {
      logger
        ..err('Failed to prepare files')
        ..detail('Error: $e');
    }

    return context.toImmutable();
  }
}

abstract interface class GitContext {
  const GitContext();

  List<String> get partiallyStagedFiles;
  List<String> get deletedFiles;
  String? get mergeHead;
  String? get mergeMode;
  String? get mergeMsg;
  String? get stashHash;
}

class GitContextSetter implements GitContext {
  GitContextSetter();

  @override
  List<String> partiallyStagedFiles = <String>[];
  @override
  List<String> deletedFiles = <String>[];
  @override
  String? mergeHead;
  @override
  String? mergeMode;
  @override
  String? mergeMsg;
  @override
  String? stashHash;

  bool get hasPartiallyStagedFiles => partiallyStagedFiles.isNotEmpty;

  ImmutableGitContext toImmutable() {
    return ImmutableGitContext(
      partiallyStagedFiles: List.unmodifiable(partiallyStagedFiles),
      deletedFiles: List.unmodifiable(deletedFiles),
      mergeHead: mergeHead,
      mergeMode: mergeMode,
      mergeMsg: mergeMsg,
      stashHash: stashHash,
    );
  }
}

class ImmutableGitContext implements GitContext {
  const ImmutableGitContext({
    required this.partiallyStagedFiles,
    required this.deletedFiles,
    required this.mergeHead,
    required this.mergeMode,
    required this.mergeMsg,
    required this.stashHash,
  });

  @override
  final List<String> partiallyStagedFiles;
  @override
  final List<String> deletedFiles;
  @override
  final String? mergeHead;
  @override
  final String? mergeMode;
  @override
  final String? mergeMsg;
  @override
  final String? stashHash;

  bool get hasPartiallyStagedFiles => partiallyStagedFiles.isNotEmpty;
}
