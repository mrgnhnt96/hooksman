import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

mixin StashMixin {
  static const _stashMessage = '__stash__git-hooks__';

  Logger get logger;

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
        '--quiet',
        '--message',
        '"$_stashMessage"',
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

  Future<int?> stash() async {
    final stashes = await Process.run('git', ['stash', 'list']);

    final out = switch (stashes.stdout) {
      final String stashes => stashes,
      _ => null,
    };

    if (out == null) {
      logger
        ..err('Failed to get stashes')
        ..detail('Error: ${stashes.stderr}');
      return null;
    }

    for (final (index, line) in out.split('\n').indexed) {
      if (!line.contains(_stashMessage)) continue;

      return index;
    }

    return null;
  }

  Future<void> dropBackupStash() async {
    final index = await stash();
    if (index == null) return;

    await Process.run('git', [
      'stash',
      'drop',
      '$index',
    ]);
  }
}
