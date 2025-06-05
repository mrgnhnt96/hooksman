import 'package:hooksman/utils/process/process.dart';
import 'package:mason_logger/mason_logger.dart';

mixin GitChecksMixin {
  Logger get logger;
  Process get process;

  Future<bool> isGitInstalled() async {
    final result = await process.run('git', ['--version']);

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
        await process.run('git', ['rev-parse', '--is-inside-work-tree']);

    if (result.exitCode != 0) {
      logger
        ..err('Not a git repository')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    return true;
  }

  Future<bool> hasAtLeastOneCommit() async {
    final result = await process.run('git', ['rev-list', '--count', 'HEAD']);

    if (result.exitCode != 0) {
      logger
        ..err('Failed to get commit count')
        ..detail('Error: ${result.stderr}');
      return false;
    }

    final count = int.tryParse(result.stdout);

    return count != null && count > 0;
  }
}
