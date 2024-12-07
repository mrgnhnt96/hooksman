import 'package:args/command_runner.dart';
// ignore: implementation_imports
import 'package:args/src/arg_results.dart';
import 'package:file/file.dart';
import 'package:hooksman/commands/register_command.dart';
import 'package:hooksman/models/compiler.dart';
import 'package:hooksman/services/git/git_service.dart';
import 'package:mason_logger/mason_logger.dart';

class GitHookRunner extends CommandRunner<int> {
  GitHookRunner({
    required this.fs,
    required this.logger,
    required GitService git,
    required Compiler compiler,
  }) : super('hooksman', 'Run git hooks') {
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
      results = argParser.parse(['register']);
    }

    return super.runCommand(results);
  }
}
