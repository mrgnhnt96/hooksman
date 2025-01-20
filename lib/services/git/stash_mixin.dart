import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

mixin StashMixin {
  static const _stashMessage = '__stash__hooksman__';

  static const backupStashMessage = '[HOOKSMAN]: backup';
  static const failsafeStashMessage = '[HOOKSMAN]: failsafe';

  Logger get logger;

  // Save stash of all staged files.
  // The `stash create` command creates a dangling
  // commit without removing any files,
  // and `stash store` saves it as an actual stash.
  Future<String?> createBackupStash() async {
    // ensure there are staged files
    final staged =
        await Process.run('git', ['diff', '--cached', '--name-only']);

    final hasFiles = switch (staged.stdout) {
      final String files => files.trim().isNotEmpty,
      _ => false,
    };

    if (!hasFiles) {
      return null;
    }

    final result = await Process.run('git', [
      'stash',
      'create',
      backupStashMessage,
    ]);

    final hash = switch (result.stdout) {
      final String hash => hash.trim(),
      _ => null,
    };

    if (hash == null) {
      logger
        ..err('Failed to create stash')
        ..detail('Error: ${result.stderr}');
      throw Exception('Failed to create stash');
    }

    // dart is running too fast for git to cache the stash,
    // resulting in a error throwing race condition
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final storeResult = await Process.run(
      'git',
      [
        'stash',
        'store',
        '--message',
        '"$_stashMessage"',
        hash,
      ],
    );

    if (storeResult.exitCode != 0) {
      logger
        ..err('Failed to store stash')
        ..detail('Error: ${storeResult.stderr}');
      throw Exception('Failed to store stash');
    }

    return hash;
  }

  Future<int?> getBackupStashHash() async {
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

  Future<bool> applyBackupStash([String? hash]) async {
    logger.detail('applying backup stash');

    final stashHash = hash ?? await getBackupStashHash();

    if (stashHash == null) {
      logger
        ..err('No backup stash found')
        ..detail('Skipping stash apply');
      return false;
    }

    // apply stash
    final apply = await Process.run('git', [
      'stash',
      'apply',
      '--quiet',
      '--index',
      '$stashHash',
    ]);

    if (apply.exitCode != 0) {
      logger
        ..err('Failed to apply stash')
        ..detail('Error: ${apply.stderr}')
        ..detail('Restoring stash before reset');

      return false;
    }

    return true;
  }

  Future<void> dropBackupStash() async {
    final index = await getBackupStashHash();
    if (index == null) return;

    await Process.run('git', [
      'stash',
      'drop',
      '$index',
    ]);
  }

  Future<bool> stashCurrentChanges() async {
    final newStash = await Process.run('git', [
      'stash',
      '--all',
      '--keep-index',
      '--message',
      failsafeStashMessage,
    ]);

    if (newStash.exitCode != 0) {
      logger
        ..err('Failed to stash current changes')
        ..detail('Error: ${newStash.stderr}');
      return false;
    }

    return true;
  }

  Future<bool> popLatestStash() async {
    final pop = await Process.run('git', [
      'stash',
      'pop',
      '--index',
    ]);

    if (pop.exitCode != 0) {
      logger
        ..err('Failed to pop backup stash')
        ..detail('Error: ${pop.stderr}');
      return false;
    }

    logger.detail('Popped latest stash');

    return true;
  }

  Future<bool> dropLatestStash() async {
    final drop = await Process.run('git', ['stash', 'drop']);

    if (drop.exitCode != 0) {
      logger
        ..err('Failed to drop stash')
        ..detail('Error: ${drop.stderr}');
      return false;
    }

    return true;
  }
}
