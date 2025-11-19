import 'package:hooksman/deps/logger.dart';
import 'package:hooksman/deps/process.dart';

mixin GitChecksMixin {
  Future<bool> isGitInstalled() async {
    final result = await process('git', ['--version']);
    final exitCode = await result.exitCode;

    if (exitCode != 0) {
      logger
        ..err('Git is not installed')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return true;
  }

  Future<bool> isGitRepository() async {
    final result = await process('git', ['rev-parse', '--is-inside-work-tree']);
    final exitCode = await result.exitCode;

    if (exitCode != 0) {
      logger
        ..err('Not a git repository')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return true;
  }

  Future<bool> hasAtLeastOneCommit() async {
    final result = await process('git', ['rev-list', '--count', 'HEAD']);
    final exitCode = await result.exitCode;

    if (exitCode != 0) {
      logger
        ..err('Failed to get commit count')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    final out = switch (result.stdout) {
      final String out => out.trim(),
      final Future<String> out => (await out).trim(),
    };

    final count = int.tryParse(out);

    return count != null && count > 0;
  }
}
