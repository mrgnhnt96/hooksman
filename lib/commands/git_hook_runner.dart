import 'package:args/command_runner.dart';
// ignore: implementation_imports
import 'package:args/src/arg_results.dart';
import 'package:file/file.dart';
import 'package:git_hooks/commands/resolve_command.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

class GitHookRunner extends CommandRunner<int> {
  GitHookRunner({
    required this.fs,
    required this.logger,
    required GitService git,
  }) : super('git_hooks', 'Run git hooks') {
    addCommand(
      ResolveCommand(
        fs: fs,
        logger: logger,
        git: git,
      ),
    );
  }

  final FileSystem fs;
  final Logger logger;

  @override
  Future<int?> runCommand(ArgResults topLevelResults) {
    var results = topLevelResults;
    final args = [...results.arguments];

    if (args.isEmpty) {
      results = argParser.parse(['resolve']);
    }

    return super.runCommand(results);
  }
}
