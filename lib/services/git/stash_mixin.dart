import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

mixin StashMixin {
  static const _stashMessage = 'stash | git_hooks';

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
        '-m',
        _stashMessage,
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
}
