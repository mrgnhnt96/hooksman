import 'package:args/command_runner.dart';
// ignore: implementation_imports
import 'package:args/src/arg_results.dart';
import 'package:file/file.dart';
import 'package:git_hooks/commands/register_command.dart';
import 'package:git_hooks/models/compiler.dart';
import 'package:git_hooks/services/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

class GitHookRunner extends CommandRunner<int> {
  GitHookRunner({
    required this.fs,
    required this.logger,
    required GitService git,
    required Compiler compiler,
  }) : super('git_hooks', 'Run git hooks') {
    addCommand(
      RegisterCommand(
        fs: fs,
        logger: logger,
        git: git,
        compiler: compiler,
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
