import 'dart:io';

import 'package:mason_logger/mason_logger.dart';

class GitService {
  const GitService({
    required this.logger,
  });

  final Logger logger;

  Future<List<String>?> getChangedFiles() async {
    final result = await Process.run('git', ['diff', '--name-only', 'HEAD']);

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

    return out.split('\n').where((element) => element.isNotEmpty).toList();
  }
}
